#pragma once

#include <cerrno>
#include <cstdint>
#include <cstring>
#include <poll.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

// A namespace FD pins the namespace after the worker exits. Use one atomic
// packet on a socketpair, never a pipe whose sender can consume its own reply.
namespace namespace_fd {

inline int64_t now_ms() {
    timespec ts{};
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return -1;
    return int64_t(ts.tv_sec) * 1000 + ts.tv_nsec / 1000000;
}

inline bool send(int socket, int fd) {
    int count = fd >= 0 ? 1 : 0;
    iovec io{&count, sizeof(count)};
    alignas(cmsghdr) char control[CMSG_SPACE(sizeof(int))]{};
    msghdr msg{};
    msg.msg_iov = &io;
    msg.msg_iovlen = 1;
    if (count) {
        msg.msg_control = control;
        msg.msg_controllen = sizeof(control);
        auto cmsg = CMSG_FIRSTHDR(&msg);
        cmsg->cmsg_level = SOL_SOCKET;
        cmsg->cmsg_type = SCM_RIGHTS;
        cmsg->cmsg_len = CMSG_LEN(sizeof(int));
        memcpy(CMSG_DATA(cmsg), &fd, sizeof(fd));
    }
    ssize_t sent;
    do { sent = sendmsg(socket, &msg, MSG_NOSIGNAL); } while (sent < 0 && errno == EINTR);
    return sent == sizeof(count);
}

inline int receive(int socket, int timeout_ms) {
    auto start = now_ms();
    if (start < 0 || timeout_ms < 0) return -1;
    auto deadline = start + timeout_ms;
    pollfd pfd{socket, POLLIN, 0};
    for (;;) {
        auto now = now_ms();
        if (now < 0) return -1;
        int remaining = now >= deadline ? 0 : static_cast<int>(deadline - now);
        int ready = poll(&pfd, 1, remaining);
        if (ready < 0 && errno == EINTR) continue;
        if (ready == 0) errno = ETIMEDOUT;
        if (ready <= 0 || !(pfd.revents & POLLIN)) return -1;
        break;
    }

    int count = -1;
    iovec io{&count, sizeof(count)};
    // Extra space lets us close unexpected received descriptors on rejection.
    alignas(cmsghdr) char control[CMSG_SPACE(sizeof(int) * 8)]{};
    msghdr msg{};
    msg.msg_iov = &io;
    msg.msg_iovlen = 1;
    msg.msg_control = control;
    msg.msg_controllen = sizeof(control);
    ssize_t size;
    do {
        size = recvmsg(socket, &msg, MSG_CMSG_CLOEXEC | MSG_DONTWAIT);
    } while (size < 0 && errno == EINTR);
    if (size < 0) return -1;

    int result = -1;
    unsigned received = 0;
    for (auto cmsg = CMSG_FIRSTHDR(&msg); cmsg; cmsg = CMSG_NXTHDR(&msg, cmsg)) {
        if (cmsg->cmsg_level != SOL_SOCKET || cmsg->cmsg_type != SCM_RIGHTS ||
            cmsg->cmsg_len < CMSG_LEN(0)) continue;
        size_t bytes = cmsg->cmsg_len - CMSG_LEN(0);
        for (size_t i = 0; i + sizeof(int) <= bytes; i += sizeof(int)) {
            int fd;
            memcpy(&fd, CMSG_DATA(cmsg) + i, sizeof(fd));
            if (received++ == 0) result = fd; else close(fd);
        }
    }
    if (size != sizeof(count) || count != 1 || received != 1 ||
        (msg.msg_flags & (MSG_CTRUNC | MSG_TRUNC))) {
        if (result >= 0) close(result);
        return -1;
    }
    return result;
}

} // namespace namespace_fd
