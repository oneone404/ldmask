#pragma once

#include <cerrno>
#include <cstdint>
#include <cstring>
#include <dirent.h>
#include <string_view>
#include <sys/mman.h>
#include <unistd.h>

// Experimental, synchronous pass only. Not a general-purpose maps filter.
namespace ldmenu_trial {
inline bool target(std::string_view path) {
    constexpr std::string_view deleted = " (deleted)";
    if (path.size() >= deleted.size() &&
        path.substr(path.size() - deleted.size()) == deleted)
        path.remove_suffix(deleted.size());
    if (path == "/data/adb/modules/ldmenu/zygisk/arm64-v8a.so" ||
        path == "/data/adb/modules/ldmenu/zygisk/x86_64.so") return true;
    constexpr std::string_view data_prefix =
        "/data/data/com.vng.playtogether/cache/tmp/ktools_loader/library_";
    constexpr std::string_view user_prefix =
        "/data/user/0/com.vng.playtogether/cache/tmp/ktools_loader/library_";
    std::string_view prefix = data_prefix;
    if (path.substr(0, user_prefix.size()) == user_prefix) prefix = user_prefix;
    if (path.size() <= prefix.size() + 3 || path.size() > prefix.size() + 128 ||
        path.substr(0, prefix.size()) != prefix ||
        path.substr(path.size() - 3) != ".so") return false;
    auto filename = path.substr(prefix.size(), path.size() - prefix.size() - 3);
    for (char c : filename)
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || c == '_'))
            return false;
    return true;
}

inline bool single_threaded() {
    DIR *tasks = opendir("/proc/self/task");
    if (!tasks) return false;
    unsigned count = 0;
    while (auto *entry = readdir(tasks)) {
        if (entry->d_name[0] >= '0' && entry->d_name[0] <= '9') ++count;
    }
    closedir(tasks);
    return count == 1;
}

inline bool remap_readonly(void *address, size_t size, int perms, bool private_map) {
    const long page = sysconf(_SC_PAGESIZE);
    // Never copy live writable/shared mappings, unreadable memory, or huge ranges.
    if (!address || !size || size > 16 * 1024 * 1024 || page <= 0 ||
        reinterpret_cast<uintptr_t>(address) % page || size % page ||
        !private_map || !(perms & PROT_READ) || (perms & PROT_WRITE) ||
        (perms & ~(PROT_READ | PROT_EXEC))) {
        errno = EINVAL;
        return false;
    }
    void *copy = mmap(nullptr, size, PROT_READ | PROT_WRITE,
                      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (copy == MAP_FAILED) return false;
    memcpy(copy, address, size);
    // Set final protection before replacing the target; it is never temporarily RWX.
    if (mprotect(copy, size, perms) != 0) {
        int error = errno;
        munmap(copy, size);
        errno = error;
        return false;
    }
    if (mremap(copy, size, size, MREMAP_MAYMOVE | MREMAP_FIXED, address) == MAP_FAILED) {
        int error = errno;
        munmap(copy, size);
        errno = error;
        return false;
    }
    return true;
}
} // namespace ldmenu_trial
