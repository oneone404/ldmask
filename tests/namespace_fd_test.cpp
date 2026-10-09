#include "../native/src/core/zygisk/namespace_fd.hpp"
#include <cassert>
#include <cstdio>
#include <dirent.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/wait.h>

static int checks;
static void pass(const char *name) { ++checks; printf("PASS %s\n", name); }
static void pair(int *s) { assert(socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, s) == 0); }
static int fd_count() {
    DIR *d = opendir("/proc/self/fd"); assert(d);
    int n = 0;
    while (readdir(d)) ++n;
    closedir(d); return n;
}
static void reap(pid_t child) {
    int status = 0;
    pid_t result;
    do { result = waitpid(child, &status, 0); } while (result < 0 && errno == EINTR);
    assert(result == child && WIFEXITED(status) && WEXITSTATUS(status) == 0);
}

static void old_pipe_reproduction() {
    int p[2]; assert(pipe(p) == 0);
    int ready = 0, consumed = -1;
    assert(write(p[1], &ready, sizeof(ready)) == sizeof(ready));
    // These are precisely the old worker's operations. It can consume READY.
    assert(read(p[0], &consumed, sizeof(consumed)) == sizeof(consumed));
    pollfd pending{p[0], POLLIN, 0};
    assert(poll(&pending, 1, 30) == 0);
    close(p[0]); close(p[1]);
    pass("old single-pipe self-read reproduced");
}

static void transferred_namespace_survives_exit() {
    int s[2]; pair(s);
    auto child = fork(); assert(child >= 0);
    if (!child) {
        close(s[0]);
        int fd = open("/proc/self/ns/mnt", O_RDONLY | O_CLOEXEC);
        if (fd < 0 || !namespace_fd::send(s[1], fd)) _exit(1);
        close(fd); close(s[1]); _exit(0);
    }
    close(s[1]);
    // Deliberately let the worker exit before parent receives its namespace.
    reap(child);
    int fd = namespace_fd::receive(s[0], 1000); assert(fd >= 0);
    assert(fcntl(fd, F_GETFD) & FD_CLOEXEC);
    struct stat st{}, current{};
    assert(fstat(fd, &st) == 0);
    assert(stat("/proc/self/ns/mnt", &current) == 0);
    assert(st.st_ino == current.st_ino && st.st_dev == current.st_dev);
    close(fd); close(s[0]); pass("namespace FD survives worker exit and is CLOEXEC");
}

static void failure_and_eof() {
    int s[2]; pair(s);
    assert(namespace_fd::send(s[1], -1));
    assert(namespace_fd::receive(s[0], 100) == -1);
    close(s[0]); close(s[1]); pass("worker failure never returns a namespace");
    pair(s); close(s[1]);
    auto start = namespace_fd::now_ms();
    assert(namespace_fd::receive(s[0], 1000) == -1);
    assert(namespace_fd::now_ms() - start < 500);
    close(s[0]); pass("worker EOF returns without blocking");
    pair(s); close(s[0]);
    int fd = open("/dev/null", O_RDONLY); assert(fd >= 0);
    assert(!namespace_fd::send(s[1], fd));
    close(fd); close(s[1]); pass("closed parent does not SIGPIPE worker");
}

static void alarm_handler(int) {}
static void bounded_timeout() {
    struct sigaction action{}, previous{}; action.sa_handler = alarm_handler;
    sigemptyset(&action.sa_mask); assert(sigaction(SIGALRM, &action, &previous) == 0);
    itimerval timer{{0, 5000}, {0, 5000}}, off{};
    assert(setitimer(ITIMER_REAL, &timer, nullptr) == 0);
    int s[2]; pair(s);
    auto start = namespace_fd::now_ms();
    assert(namespace_fd::receive(s[0], 80) == -1 && errno == ETIMEDOUT);
    auto elapsed = namespace_fd::now_ms() - start;
    assert(elapsed >= 60 && elapsed < 500);
    assert(setitimer(ITIMER_REAL, &off, nullptr) == 0);
    assert(sigaction(SIGALRM, &previous, nullptr) == 0);
    close(s[0]); close(s[1]); pass("EINTR preserves monotonic timeout deadline");
}

static void malformed_packets() {
    int baseline = fd_count();
    int s[2]; pair(s);
    int value = 1;
    assert(send(s[1], &value, sizeof(value), MSG_NOSIGNAL) == sizeof(value));
    assert(namespace_fd::receive(s[0], 100) == -1);
    char short_packet = 1;
    assert(send(s[1], &short_packet, 1, MSG_NOSIGNAL) == 1);
    assert(namespace_fd::receive(s[0], 100) == -1);
    char large[32]{};
    assert(send(s[1], large, sizeof(large), MSG_NOSIGNAL) == sizeof(large));
    assert(namespace_fd::receive(s[0], 100) == -1);
    const int counts[] = {2, 16};
    for (int n : counts) {
        int fd = open("/dev/null", O_RDONLY); assert(fd >= 0);
        int fds[16]; for (int i = 0; i < n; ++i) fds[i] = fd;
        alignas(cmsghdr) char control[CMSG_SPACE(sizeof(fds))]{};
        iovec io{&value, sizeof(value)};
        msghdr msg{}; msg.msg_iov = &io; msg.msg_iovlen = 1;
        msg.msg_control = control; msg.msg_controllen = CMSG_SPACE(sizeof(int) * n);
        auto c = CMSG_FIRSTHDR(&msg);
        c->cmsg_len = CMSG_LEN(sizeof(int) * n);
        c->cmsg_level = SOL_SOCKET; c->cmsg_type = SCM_RIGHTS;
        memcpy(CMSG_DATA(c), fds, sizeof(int) * n);
        assert(sendmsg(s[1], &msg, MSG_NOSIGNAL) == sizeof(value));
        assert(namespace_fd::receive(s[0], 100) == -1);
        close(fd);
    }
    close(s[0]); close(s[1]);
    assert(fd_count() == baseline); pass("malformed/truncated/multiple FD packets rejected without leaks");
}

static void fd_zero_and_repeated_transfer() {
    int baseline = fd_count();
    for (int i = 0; i < 100; ++i) {
        int s[2]; pair(s);
        int fd = open("/dev/null", O_RDONLY | O_CLOEXEC); assert(fd >= 0);
        assert(namespace_fd::send(s[1], fd));
        int saved = dup(0); assert(saved >= 0); close(0);
        int received = namespace_fd::receive(s[0], 100);
        assert(received == 0 && (fcntl(received, F_GETFD) & FD_CLOEXEC));
        close(received); assert(dup2(saved, 0) == 0); close(saved);
        close(fd); close(s[0]); close(s[1]);
    }
    assert(fd_count() == baseline); pass("100 transfers accept FD 0 without leaks");
}

int main() {
    old_pipe_reproduction(); transferred_namespace_survives_exit();
    failure_and_eof(); bounded_timeout(); malformed_packets();
    fd_zero_and_repeated_transfer();
    printf("RESULT %d checks passed (no root/mount/game operations)\n", checks);
}
