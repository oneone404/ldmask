#include "../native/src/core/zygisk/ldmenu_fd.hpp"
#include <cassert>
#include <cstdio>
#include <cstdlib>

int main() {
    using namespace ldmenu_loader_trial;
    char name[] = "/data/local/tmp/ldmenu-fd-fixture-XXXXXX";
    int original = mkstemp(name); assert(original >= 0);
    Elf64_Ehdr elf{};
    memcpy(elf.e_ident, ELFMAG, SELFMAG);
    elf.e_ident[EI_CLASS] = ELFCLASS64;
    elf.e_ident[EI_DATA] = ELFDATA2LSB;
    elf.e_type = ET_DYN; elf.e_machine = EM_AARCH64;
    assert(write(original, &elf, sizeof(elf)) == sizeof(elf));
    bool created;
    int copy = capture_file(name, &created);
    assert(copy >= 0 && created);
    Elf64_Ehdr result{};
    assert(pread(copy, &result, sizeof(result), 0) == sizeof(result));
    assert(memcmp(&elf, &result, sizeof(elf)) == 0);
    puts("PASS exact immutable ELF snapshot");
    int seals = fcntl(copy, F_GET_SEALS);
    assert((seals & (F_SEAL_WRITE | F_SEAL_GROW | F_SEAL_SHRINK | F_SEAL_SEAL)) ==
           (F_SEAL_WRITE | F_SEAL_GROW | F_SEAL_SHRINK | F_SEAL_SEAL));
    assert(pwrite(copy, "x", 1, 0) == -1 && errno == EPERM);
    puts("PASS write/grow/shrink sealed");
    assert(capture_file(name, &created) == copy && !created);
    char indirect[64]; snprintf(indirect, sizeof(indirect), "/proc/self/fd/%d", copy);
    char target[256]{}; assert(readlink(indirect, target, sizeof(target) - 1) > 0);
    assert(strstr(target, "memfd:jit-cache") && !strstr(target, "ldmenu"));
    puts("PASS bounded cache reuse; no original path on FD");
    // Cache must not reuse an FD that was closed by an external sanitizer.
    assert(close(copy) == 0);
    assert(capture_file(name, &created) >= 0 && created);
    puts("PASS closed FD regenerated");
    assert(lseek(original, 7, SEEK_SET) == 7);
    assert(capture_file(nullptr, &created, original) >= 0 && !created);
    assert(lseek(original, 0, SEEK_CUR) == 7);
    puts("PASS supplied FD snapshot preserves source offset");
    struct stat source_info{};
    assert(fstat(original, &source_info) == 0);
    struct timespec times[2] = {source_info.st_atim, source_info.st_mtim};
    times[1].tv_nsec = (times[1].tv_nsec + 1) % 1000000000;
    assert(futimens(original, times) == 0);
    int previous_copy = capture_file(name, &created);
    assert(previous_copy >= 0 && created);
    assert(capture_file(name, &created) == previous_copy && !created);
    puts("PASS nanosecond modification invalidates cached snapshot");
    size_t previous_total = total_bytes;
    total_bytes = 32 * 1024 * 1024;
    times[1].tv_nsec = (times[1].tv_nsec + 1) % 1000000000;
    assert(futimens(original, times) == 0);
    assert(capture_file(name, &created) == -1 && !created);
    total_bytes = previous_total;
    puts("PASS snapshot byte budget refuses further allocation");
    elf.e_machine = EM_X86_64;
    assert(pwrite(original, &elf, sizeof(elf), 0) == sizeof(elf));
    assert(capture_file(name, &created) == -1 && !created);
    puts("PASS wrong ELF architecture rejected");
    assert(capture_file("/does/not/exist", &created) == -1 && !created);
    assert(capture_file("/proc/self/status", &created) == -1 && !created);
    assert(unlink(name) == 0); close(original);
    for (auto &file : files) if (file.fd >= 0) close(file.fd);
    puts("PASS invalid source refused; original fixture removed");
    puts("PASS 9 checks");
}
