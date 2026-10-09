#pragma once
#include <cerrno>
#include <cstring>
#include <cstdio>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

namespace ldmenu_cache_trial {
constexpr const char *prefixes[]={
    "/data/data/com.vng.playtogether/cache/tmp/",
    "/data/user/0/com.vng.playtogether/cache/tmp/"};
inline const char *translate(const char *path,char (&out)[4096],bool enabled,int dirfd=AT_FDCWD) {
    if(!enabled || !path) return path;
    size_t length=strnlen(path,sizeof(out));
    if(length==sizeof(out)) return path;
    for(auto prefix:prefixes) {
        size_t n=strlen(prefix);
        if(length<n || strncmp(path,prefix,n)) continue;
        const char *suffix=path+n;
        constexpr size_t old_length=13; // ktools_loader
        if(strncmp(suffix,"ktools_loader",old_length) ||
           (suffix[old_length] && suffix[old_length]!='/')) return path;
        // Refuse traversal/ambiguous separators rather than alter unrelated paths.
        const char *rest=suffix+old_length;
        if(strstr(rest,"//") || strstr(rest,"/../") || strstr(rest,"/./") ||
           strcmp(rest,"/..")==0 || strcmp(rest,"/.")==0) return path;
        snprintf(out,sizeof(out),"%s.runtime%s",prefix,rest);
        return out;
    }
    // A relative directory name is rewritten only under the exact cache/tmp FD.
    if(dirfd>=0 && strcmp(path,"ktools_loader")==0) {
        char proc[64],parent[4096];
        snprintf(proc,sizeof(proc),"/proc/self/fd/%d",dirfd);
        ssize_t n=readlink(proc,parent,sizeof(parent)-1);
        if(n>0) {
            parent[n]=0;
            for(auto prefix:prefixes) {
                size_t length=strlen(prefix);
                if(static_cast<size_t>(n)==length-1 && !strncmp(parent,prefix,length-1)) {
                    strcpy(out,".runtime"); return out;
                }
            }
        }
    }
    return path;
}
inline bool migrate_at(int parent) {
    struct stat root{},old{},dest{};
    if(fstat(parent,&root) || !S_ISDIR(root.st_mode) || root.st_uid!=getuid()) return false;
    int old_rc=fstatat(parent,"ktools_loader",&old,AT_SYMLINK_NOFOLLOW);
    int old_errno=errno;
    int dest_rc=fstatat(parent,".runtime",&dest,AT_SYMLINK_NOFOLLOW);
    int dest_errno=errno;
    if(!old_rc && (!S_ISDIR(old.st_mode) || old.st_uid!=getuid())) return false;
    if(!dest_rc && (!S_ISDIR(dest.st_mode) || dest.st_uid!=getuid())) return false;
    if(!old_rc && !dest_rc) return false; // Never merge/overwrite two caches.
    if(old_rc && old_errno!=ENOENT) return false;
    if(dest_rc && dest_errno!=ENOENT) return false;
    if(old_rc) return !dest_rc || mkdirat(parent,".runtime",0700)==0;
    // Atomic NOREPLACE: a concurrently-created destination is never overwritten.
    return syscall(__NR_renameat2,parent,"ktools_loader",parent,".runtime",1U)==0;
}
inline bool migrate() {
    const char *parent="/data/user/0/com.vng.playtogether/cache/tmp";
    if(mkdir(parent,0700) && errno!=EEXIST) return false;
    int fd=open(parent,O_RDONLY|O_CLOEXEC|O_DIRECTORY|O_NOFOLLOW);
    if(fd<0) return false;
    bool result=migrate_at(fd);
    close(fd); return result;
}
inline bool restore_at(int parent,uid_t owner) {
    struct stat root{},old{},dest{};
    if(fstat(parent,&root) || !S_ISDIR(root.st_mode) || root.st_uid!=owner) return false;
    int old_rc=fstatat(parent,"ktools_loader",&old,AT_SYMLINK_NOFOLLOW); int old_errno=errno;
    int dest_rc=fstatat(parent,".runtime",&dest,AT_SYMLINK_NOFOLLOW); int dest_errno=errno;
    if(!old_rc && (!S_ISDIR(old.st_mode) || old.st_uid!=owner)) return false;
    if(!dest_rc && (!S_ISDIR(dest.st_mode) || dest.st_uid!=owner)) return false;
    if(!old_rc && !dest_rc) return false;
    if(old_rc && old_errno!=ENOENT) return false;
    if(dest_rc && dest_errno!=ENOENT) return false;
    if(dest_rc) return true; // No migrated cache: nothing to change.
    return syscall(__NR_renameat2,parent,".runtime",parent,"ktools_loader",1U)==0;
}
}
