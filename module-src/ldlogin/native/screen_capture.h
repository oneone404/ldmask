#pragma once
#include <algorithm>
#include <cerrno>
#include <csignal>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <poll.h>
#include <sys/prctl.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include <vector>

struct Image {
    unsigned width = 0, height = 0;
    std::vector<unsigned char> rgba;
};
static long long screen_clock_ms() {
    timespec ts{};
    if (clock_gettime(CLOCK_BOOTTIME, &ts) != 0) return -1;
    return ts.tv_sec * 1000ll + ts.tv_nsec / 1000000;
}
// Android raw screenshots may carry a 12- or 16-byte header. Bound dimensions
// before allocating and require an exact payload and supported pixel format.
static bool decode_raw_screen(std::vector<unsigned char>& raw, Image& image) {
    if (raw.size() < 12) return false;
    uint32_t h[3]; std::memcpy(h, raw.data(), sizeof(h));
    if (!h[0] || !h[1] || h[0] > 4096 || h[1] > 4096 || size_t(h[0]) * h[1] > 4 * 1024 * 1024 || (h[2] != 1 && h[2] != 2)) return false;
    const size_t bytes = size_t(h[0]) * h[1] * 4;
    if (raw.size() != bytes + 12 && raw.size() != bytes + 16) return false;
    const size_t header = raw.size() - bytes;
    raw.erase(raw.begin(), raw.begin() + header);
    image.width = h[0]; image.height = h[1]; image.rgba.swap(raw);
    return true;
}
static bool capture_screen(Image& image, const char* program = "/system/bin/screencap", int timeout_ms = 5000) {
    const long long start = screen_clock_ms();
    if (start < 0) return false;
    const long long deadline = start + timeout_ms;
    int fds[2];
    if (pipe2(fds, O_CLOEXEC | O_NONBLOCK) != 0) return false;
    const pid_t owner = getpid();
    pid_t pid = fork();
    if (pid < 0) { close(fds[0]); close(fds[1]); return false; }
    if (pid == 0) {
        if (prctl(PR_SET_PDEATHSIG, SIGKILL) != 0 || getppid() != owner) _exit(127);
        int flags = fcntl(fds[1], F_GETFL);
        if (flags < 0 || fcntl(fds[1], F_SETFL, flags & ~O_NONBLOCK) != 0 || dup2(fds[1], STDOUT_FILENO) < 0) _exit(127);
        close(fds[0]); close(fds[1]);
        execl(program, program, static_cast<char*>(nullptr)); _exit(127);
    }
    close(fds[1]);
    std::vector<unsigned char> raw;
    bool eof = false, ok = true, reaped = false;
    size_t limit = 16;
    unsigned char buf[65536];
    while (!eof && ok) {
        const long long now = screen_clock_ms();
        if (now < 0 || now >= deadline) { ok = false; break; }
        pollfd p{fds[0], POLLIN, 0};
        int ready = poll(&p, 1, int(deadline - now));
        if (ready < 0) { if (errno == EINTR) continue; ok = false; break; }
        if (!ready || (p.revents & (POLLERR | POLLNVAL))) { ok = false; break; }
        for (;;) {
            // Read the fixed header first; never trust an unbounded producer.
            size_t count = raw.size() < 12 ? 12 - raw.size() : sizeof(buf);
            ssize_t got = read(fds[0], buf, count);
            if (!got) { eof = true; break; }
            if (got < 0) {
                if (errno == EINTR) continue;
                if (errno != EAGAIN) ok = false;
                break;
            }
            if (raw.size() + size_t(got) > limit) { ok = false; break; }
            raw.insert(raw.end(), buf, buf + got);
            if (raw.size() == 12) {
                uint32_t h[3]; std::memcpy(h, raw.data(), 12);
                if (!h[0] || !h[1] || h[0] > 4096 || h[1] > 4096 || size_t(h[0]) * h[1] > 4 * 1024 * 1024 || (h[2] != 1 && h[2] != 2)) { ok = false; break; }
                limit = size_t(h[0]) * h[1] * 4 + 16;
                raw.reserve(limit);
            }
            if (screen_clock_ms() >= deadline) { ok = false; break; }
        }
    }
    close(fds[0]);
    int status = 0;
    if (ok && eof) {
        for (;;) {
            pid_t done = waitpid(pid, &status, WNOHANG);
            if (done == pid) { reaped = true; break; }
            if (done < 0 && errno != EINTR) { ok = false; break; }
            if (screen_clock_ms() >= deadline) { ok = false; break; }
            poll(nullptr, 0, 10);
        }
    }
    if (!reaped) {
        kill(pid, SIGKILL);
        // Do not hang on a child stuck in kernel I/O; init reaps it after exit.
        waitpid(pid, &status, WNOHANG);
        return false;
    }
    return ok && WIFEXITED(status) && WEXITSTATUS(status) == 0 && decode_raw_screen(raw, image);
}
