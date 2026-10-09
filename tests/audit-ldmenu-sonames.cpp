#include "ldmenu_soname.hpp"
#include <dirent.h>
#include <fcntl.h>
#include <cstdio>
#include <cstdlib>
#include <cerrno>
int main(int argc,char **argv) {
    if(getuid()!=0 || argc!=2) return 20;
    char *end=nullptr;long pid=strtol(argv[1],&end,10);
    if(!end || *end || pid<1 || pid>1000000) return 21;
    char path[128],cmdline[64]{};
    snprintf(path,sizeof(path),"/proc/%ld/cmdline",pid);
    int cmd=open(path,O_RDONLY|O_CLOEXEC);if(cmd<0) return 22;
    ssize_t bytes=read(cmd,cmdline,sizeof(cmdline)-1);close(cmd);
    if(bytes<=0 || strcmp(cmdline,"com.vng.playtogether")) return 23;
    snprintf(path,sizeof(path),"/proc/%ld/fd",pid);
    DIR *dir=opendir(path);if(!dir) return 24;
    int matched=0;
    while(auto *entry=readdir(dir)) {
        char *tail=nullptr;long number=strtol(entry->d_name,&tail,10);
        if(!tail || *tail || number<0 || number>4096) continue;
        snprintf(path,sizeof(path),"/proc/%ld/fd/%ld",pid,number);
        char target[128]{};ssize_t n=readlink(path,target,sizeof(target)-1);
        if(n<=0 || strcmp(target,"/memfd:jit-cache (deleted)")) continue;
        // Check metadata before reading; never read sockets, pipes or other files.
        struct stat link{};
        if(stat(path,&link) || !S_ISREG(link.st_mode) ||
           (link.st_size!=3328520 && link.st_size!=9322556)) continue;
        int fd=open(path,O_RDONLY|O_CLOEXEC);if(fd<0) continue;
        struct stat actual{};
        if(fstat(fd,&actual) || actual.st_ino!=link.st_ino || actual.st_dev!=link.st_dev || actual.st_size!=link.st_size) {close(fd);continue;}
        const char *expected=actual.st_size==3328520 ? "libNativeBridge.so" : "libnative.so";
        const char *old=actual.st_size==3328520 ? "libLoaderZygisk.so" : "libktools.so";
        bool neutral=ldmenu_soname_trial::matches(fd,expected);
        bool legacy=ldmenu_soname_trial::matches(fd,old);
        printf("ARM_METADATA fd=%ld bytes=%lld neutral_soname=%d legacy_soname=%d sealed=%d\n",
            number,static_cast<long long>(actual.st_size),neutral,legacy,(fcntl(fd,F_GET_SEALS)&F_SEAL_WRITE)!=0);
        close(fd);if(neutral&&!legacy) ++matched;
    }
    closedir(dir);
    return matched==2 ? 0 : 25;
}
