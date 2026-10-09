#pragma once
#include "config_gate.h"
#include <cerrno>
#include <csignal>
#include <cstring>
#include <fcntl.h>
#include <poll.h>
#include <sys/inotify.h>
#include <sys/prctl.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

static volatile sig_atomic_t config_watch_running = 1;
static void config_watch_stop(int) { config_watch_running = 0; }
static long long config_boot_ms() {
    timespec value{};
    if (clock_gettime(CLOCK_BOOTTIME, &value) != 0) return -1;
    return value.tv_sec * 1000ll + value.tv_nsec / 1000000;
}
static bool config_same_snapshot(const struct stat& a, const struct stat& b) {
    return a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_size == b.st_size &&
        a.st_mtim.tv_sec == b.st_mtim.tv_sec && a.st_mtim.tv_nsec == b.st_mtim.tv_nsec &&
        a.st_ctim.tv_sec == b.st_ctim.tv_sec && a.st_ctim.tv_nsec == b.st_ctim.tv_nsec;
}
static LDLoginSettings config_watch_value(const char* path) {
    struct stat before{}, after{};
    LDLoginSettings settings;
    if (stat(path, &before) == 0 && S_ISREG(before.st_mode) &&
        read_settings_file(path, settings) && stat(path, &after) == 0 &&
        config_same_snapshot(before, after)) return settings;
    return LDLoginSettings{};
}

// One persistent child, one private FIFO. No state files or repeated process spawning.
// Frames fit in PIPE_BUF and are sent on state changes and 60-second resyncs.
static int watch_config_gate(const char* path, pid_t owner) {
    if (owner <= 1 || getppid() != owner || prctl(PR_SET_PDEATHSIG, SIGTERM) != 0 || getppid() != owner) return 3;
    signal(SIGTERM, config_watch_stop);
    signal(SIGINT, config_watch_stop);
    int fd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (fd < 0) return 3; // Never fall back to an old enable switch.
    int flags = fcntl(STDOUT_FILENO, F_GETFL);
    if (flags < 0 || fcntl(STDOUT_FILENO, F_SETFL, flags | O_NONBLOCK) < 0) { close(fd); return 3; }
    std::string file(path);
    size_t slash = file.find_last_of('/');
    if (slash == std::string::npos) { close(fd); return 3; }
    std::string parent = file.substr(0, slash), name = file.substr(slash + 1);
    if (parent.empty() || name.empty()) { close(fd); return 3; }
    int wd = -1, last = -1, last_logging = -1;
    unsigned long long sequence = 0;
    const long long interval = 60000;
    long long next_check = config_boot_ms() + interval;
    long long next_retry = 0;
    int retry_ms = 1000;
    bool dirty = true, heartbeat = true;
    auto publish = [&](const LDLoginSettings& settings) {
        long long now = config_boot_ms();
        if (now < 0) return false;
        char frame[128];
        int length = std::snprintf(frame, sizeof(frame), "STATE %d %llu %d %lld %d\n",
            getpid(), ++sequence, settings.enabled ? 1 : 0, now / 1000, settings.logging ? 1 : 0);
        ssize_t sent;
        do { sent = write(STDOUT_FILENO, frame, size_t(length)); } while (sent < 0 && errno == EINTR && config_watch_running);
        // Backpressure/closed consumer is fatal: do not silently lose an OFF state.
        return sent == length;
    };
    int result_code = 0;
    while (config_watch_running && getppid() == owner) {
        long long now = config_boot_ms();
        if (now < 0) { result_code = 3; break; }
        if (wd < 0 && now >= next_retry) {
            wd = inotify_add_watch(fd, parent.c_str(), IN_CLOSE_WRITE | IN_MOVED_TO | IN_MOVED_FROM |
                IN_DELETE | IN_ATTRIB | IN_DELETE_SELF | IN_MOVE_SELF | IN_ONLYDIR);
            if (wd >= 0) { retry_ms = 1000; dirty = true; }
            else { next_retry = now + retry_ms; retry_ms = std::min(30000, retry_ms * 2); }
        }
        if (now >= next_check) { heartbeat = true; dirty = true; next_check = now + interval; }
        if (dirty || heartbeat) {
            // If a watch cannot be established, keep the gate OFF.
            LDLoginSettings settings = wd >= 0 ? config_watch_value(path) : LDLoginSettings{};
            if (heartbeat || last != int(settings.enabled) || last_logging != int(settings.logging)) {
                if (!publish(settings)) { result_code = 3; break; }
                last = settings.enabled ? 1 : 0;
                last_logging = settings.logging ? 1 : 0;
            }
            dirty = false; heartbeat = false;
        }
        now = config_boot_ms();
        long long deadline = wd < 0 ? std::min(next_check, next_retry) : next_check;
        pollfd watcher{fd, POLLIN, 0};
        int result = poll(&watcher, 1, int(std::max(0ll, deadline - now)));
        if (!config_watch_running) break;
        if (result < 0) { if (errno == EINTR) continue; result_code = 3; break; }
        if (result > 0 && (watcher.revents & (POLLERR | POLLHUP | POLLNVAL))) { result_code = 3; break; }
        if (result > 0 && (watcher.revents & POLLIN)) {
            alignas(inotify_event) char buffer[4096];
            ssize_t bytes;
            while ((bytes = read(fd, buffer, sizeof(buffer))) > 0) {
                for (size_t offset = 0; offset + sizeof(inotify_event) <= size_t(bytes);) {
                    auto* event = reinterpret_cast<const inotify_event*>(buffer + offset);
                    if (offset + sizeof(*event) + event->len > size_t(bytes)) { dirty = true; break; }
                    if (event->mask & IN_Q_OVERFLOW) { dirty = true; heartbeat = true; }
                    if (event->wd == wd && (event->mask & (IN_IGNORED | IN_DELETE_SELF | IN_MOVE_SELF | IN_UNMOUNT))) {
                        int previous = wd; wd = -1;
                        inotify_rm_watch(fd, previous);
                        next_retry = config_boot_ms(); retry_ms = 1000; dirty = true;
                    }
                    if (event->wd == wd && event->len && name == event->name) dirty = true;
                    offset += sizeof(*event) + event->len;
                }
            }
            if (bytes < 0 && errno != EAGAIN && errno != EINTR) { result_code = 3; break; }
        }
    }
    close(fd);
    return result_code;
}
