#pragma once

#include "ldmenu_remap.hpp"
#include <elf.h>
#include <cstddef>
#include <fcntl.h>
#include <linux/memfd.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/syscall.h>

// Bounded immutable library snapshots. Does not modify a live mapping, the
// original file, or any unrelated library. All retained FDs die with the app.
namespace ldmenu_loader_trial {
struct Snapshot {
    uint64_t dev{};
    uint64_t inode{};
    int64_t size{};
    int64_t modified{};
    int64_t modified_nsec{};
    uint64_t copy_inode{};
    int fd = -1;
    bool (*transform)(int) = nullptr;
};
inline pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
inline Snapshot files[8];
inline size_t total_bytes = 0;

inline int capture_file(const char *path, bool *created, int supplied_fd = -1,
                        bool (*transform)(int) = nullptr) {
    *created = false;
    int source = supplied_fd >= 0 ? fcntl(supplied_fd, F_DUPFD_CLOEXEC, 0) :
                                   open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (source < 0) return -1;
    struct stat before{};
    Elf64_Ehdr elf{};
    if (fstat(source, &before) != 0 || !S_ISREG(before.st_mode) ||
        before.st_size < static_cast<off_t>(sizeof(elf)) || before.st_size > 16 * 1024 * 1024 ||
        pread(source, &elf, sizeof(elf), 0) != sizeof(elf) ||
        memcmp(elf.e_ident, ELFMAG, SELFMAG) || elf.e_ident[EI_CLASS] != ELFCLASS64 ||
        elf.e_ident[EI_DATA] != ELFDATA2LSB || elf.e_type != ET_DYN || elf.e_machine != EM_AARCH64) {
        close(source);
        return -1;
    }
    pthread_mutex_lock(&lock);
    Snapshot *slot = nullptr;
    for (auto &file : files) {
        if (file.fd >= 0) {
            struct stat retained{};
            if (fstat(file.fd, &retained) != 0 || retained.st_ino != file.copy_inode ||
                retained.st_size != file.size) file.fd = -1;
        }
        if (file.fd >= 0 && file.transform == transform && file.dev == before.st_dev && file.inode == before.st_ino &&
            file.size == before.st_size && file.modified == before.st_mtime &&
            file.modified_nsec == before.st_mtim.tv_nsec) {
            int fd = file.fd;
            pthread_mutex_unlock(&lock);
            close(source);
            return fd;
        }
        if (!slot && file.fd < 0) slot = &file;
    }
    int copy = slot && total_bytes + before.st_size <= 32 * 1024 * 1024 ?
                     static_cast<int>(syscall(__NR_memfd_create, "jit-cache",
                                              MFD_CLOEXEC | MFD_ALLOW_SEALING)) : -1;
    bool ok = copy >= 0;
    char buffer[8192];
    for (off_t offset = 0; ok && offset < before.st_size;) {
        ssize_t count;
        do { count = pread(source, buffer, sizeof(buffer), offset); } while (count < 0 && errno == EINTR);
        if (count <= 0) { ok = false; break; }
        ssize_t written = 0;
        while (written < count) {
            ssize_t n = write(copy, buffer + written, count - written);
            if (n < 0 && errno == EINTR) continue;
            if (n <= 0) { ok = false; break; }
            written += n;
        }
        offset += count;
    }
    struct stat after{};
    ok = ok && fstat(source, &after) == 0 && after.st_size == before.st_size &&
         after.st_mtime == before.st_mtime && after.st_ctime == before.st_ctime &&
         after.st_mtim.tv_nsec == before.st_mtim.tv_nsec &&
         after.st_ctim.tv_nsec == before.st_ctim.tv_nsec;
    // Private ELF relocations work on a sealed, read-only backing file.
    ok = ok && (!transform || transform(copy));
    ok = ok && fcntl(copy, F_ADD_SEALS, F_SEAL_WRITE | F_SEAL_GROW | F_SEAL_SHRINK | F_SEAL_SEAL) == 0;
    close(source);
    if (ok) {
        struct stat retained{};
        fstat(copy, &retained);
        *slot = {before.st_dev, before.st_ino, before.st_size, before.st_mtime,
                 before.st_mtim.tv_nsec, retained.st_ino, copy, transform};
        *created = true;
        total_bytes += before.st_size;
    } else if (copy >= 0) {
        close(copy);
        copy = -1;
    }
    pthread_mutex_unlock(&lock);
    return copy;
}

using Load = void *(*)(const char *, int);
using LoadExt = void *(*)(const char *, int, void *);
// Prefix verified against Android 9's NativeBridgeCallbacks v3/v4 ABI.
// https://android.googlesource.com/platform/system/core/+/android-9.0.0_r1/libnativebridge/include/nativebridge/native_bridge.h
struct BridgePrefix {
    uint32_t version;
    void *initialize;
    Load load;
    void *callbacks[11];
    LoadExt load_ext;
};
#if defined(__x86_64__)
static_assert(offsetof(BridgePrefix, load) == 16);
static_assert(offsetof(BridgePrefix, load_ext) == 112);
static_assert(sizeof(BridgePrefix) == 120);
#endif
} // namespace ldmenu_loader_trial
