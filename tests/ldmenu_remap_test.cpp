#include "../native/src/core/zygisk/ldmenu_remap.hpp"
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <fcntl.h>
#include <pthread.h>
#include <sys/stat.h>

static void *thread(void *arg) {
    auto *s = static_cast<int *>(arg);
    char byte;
    assert(read(s[0], &byte, 1) == 1);
    return nullptr;
}
int main() {
    using namespace ldmenu_trial;
    assert(target("/data/adb/modules/ldmenu/zygisk/arm64-v8a.so"));
    assert(target("/data/adb/modules/ldmenu/zygisk/x86_64.so (deleted)"));
    assert(target("/data/data/com.vng.playtogether/cache/tmp/ktools_loader/library_188_abc012.so"));
    assert(target("/data/user/0/com.vng.playtogether/cache/tmp/ktools_loader/library_188_abc012.so"));
    assert(!target("/data/user/10/com.vng.playtogether/cache/tmp/ktools_loader/library_188_abc012.so"));
    assert(!target("/data/user/0/com.other/cache/tmp/ktools_loader/library_188_abc012.so"));
    assert(!target("/data/user/0/com.vng.playtogether/cache/tmp/ktools_loader/library_../other.so"));
    assert(!target("/data/user/0/com.vng.playtogether/cache/tmp/ktools_loader/library_.so"));
    assert(!target("/data/adb/modules/ldmenu/zygisk/arm64-v8a.so.fake"));
    assert(!target("/data/adb/modules/other/zygisk/arm64-v8a.so"));
    assert(!target("/data/data/com.other/cache/tmp/ktools_loader/library_188_abc012.so"));
    assert(!target("/data/data/com.vng.playtogether/cache/tmp/ktools_loader/library_../other.so"));
    assert(!target("/data/data/com.vng.playtogether/cache/tmp/ktools_loader/library_.so"));
    puts("PASS strict path allowlist");
    assert(single_threaded());
    int s[2]; assert(pipe(s) == 0);
    pthread_t worker;
    assert(pthread_create(&worker, nullptr, thread, s) == 0);
    assert(!single_threaded());
    assert(write(s[1], "x", 1) == 1);
    assert(pthread_join(worker, nullptr) == 0);
    close(s[0]); close(s[1]);
    assert(single_threaded());
    puts("PASS threaded process refused");
    const size_t size = static_cast<size_t>(sysconf(_SC_PAGESIZE));
    char path[] = "/data/local/tmp/ldmenu-fixture-XXXXXX";
    int fd = mkstemp(path); assert(fd >= 0); assert(unlink(path) == 0);
    assert(ftruncate(fd, size) == 0);
    const char bytes[] = "readonly mapping payload";
    assert(pwrite(fd, bytes, sizeof(bytes), 0) == sizeof(bytes));
    void *p = mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);
    assert(p != MAP_FAILED); close(fd);
    assert(!remap_readonly(p, size, PROT_READ | PROT_WRITE, true));
    assert(!remap_readonly(p, size, PROT_READ, false));
    assert(!remap_readonly(p, size, PROT_NONE, true));
    assert(!remap_readonly(p, size - 1, PROT_READ, true));
    assert(!remap_readonly(nullptr, size, PROT_READ, true));
    assert(!remap_readonly(p, 17 * 1024 * 1024, PROT_READ, true));
    assert(memcmp(p, bytes, sizeof(bytes)) == 0);
    puts("PASS unsafe ranges rejected unchanged");
    assert(remap_readonly(p, size, PROT_READ, true));
    assert(memcmp(p, bytes, sizeof(bytes)) == 0);
    FILE *maps = fopen("/proc/self/maps", "r"); assert(maps);
    char line[1024]; bool matched = false;
    while (fgets(line, sizeof(line), maps)) {
        unsigned long a, b, offset, inode; char perms[5];
        if (sscanf(line, "%lx-%lx %4s %lx %*s %lu", &a, &b, perms, &offset, &inode) == 5 &&
            reinterpret_cast<uintptr_t>(p) >= a && reinterpret_cast<uintptr_t>(p) < b) {
            assert(perms[0] == 'r' && perms[1] == '-' && perms[2] == '-' && perms[3] == 'p');
            assert(inode == 0); matched = true;
        }
    }
    fclose(maps); assert(matched); assert(munmap(p, size) == 0);
    puts("PASS bytes and permissions preserved; anonymous backing confirmed");
    puts("PASS 4 checks");
}
