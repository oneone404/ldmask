#include "ldmenu_cachepath.hpp"
int main() {
    if(getuid()!=0) return 20;
    const char *parent="/data/user/0/com.vng.playtogether/cache/tmp";
    int fd=open(parent,O_RDONLY|O_CLOEXEC|O_DIRECTORY|O_NOFOLLOW);
    if(fd<0) return errno==ENOENT ? 0 : 21;
    struct stat st{};
    if(fstat(fd,&st) || st.st_uid<10000) {close(fd);return 22;}
    bool result=ldmenu_cache_trial::restore_at(fd,st.st_uid);
    if(result) fsync(fd);
    close(fd);return result ? 0 : 23;
}
