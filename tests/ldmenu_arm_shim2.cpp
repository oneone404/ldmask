#include "ldmenu_arm_import.hpp"
#include "ldmenu_cachepath.hpp"
#include "ldmenu_soname.hpp"
#include "../native/src/core/zygisk/ldmenu_fd.hpp"
#include <android/log.h>
#include <dlfcn.h>
#include <jni.h>
#include <cstdarg>
#include <dirent.h>
#include <cstdio>

// Experimental upgrade of shim1. Never modifies credentials or original ELF bytes.
extern "C" const unsigned char ldmenu_embedded_start[],ldmenu_embedded_end[];
static bool cache_ready;
static void *(*previous_dlopen)(const char *,int);
static FILE *(*previous_fopen)(const char *,const char *);
static int (*previous_open)(const char *,int,...);
static int (*previous_open2)(const char *,int);
static int (*previous_openat)(int,const char *,int,...);
static int (*previous_stat)(const char *,struct stat *);
static DIR *(*previous_opendir)(const char *);
static int (*previous_mkdir)(const char *,mode_t);
static int (*previous_rename)(const char *,const char *);
static int (*previous_unlink)(const char *);
static int (*previous_unlinkat)(int,const char *,int);
static void *original_handle;
static int original_fd=-1;
static unsigned audit_count;
static void audit(const char *event,bool result) {
#ifndef LDMENU_SHIM_RELEASE
    if(__atomic_fetch_add(&audit_count,1U,__ATOMIC_RELAXED)<12)
        __android_log_print(ANDROID_LOG_INFO,"LDMenuArmTrial","%s pid=%d result=%d",event,getpid(),result);
#else
    (void)event; (void)result;
#endif
}
static const char *path(const char *value,char (&out)[4096],int dirfd=AT_FDCWD) {
    return ldmenu_cache_trial::translate(value,out,cache_ready,dirfd);
}
static bool has_mode(int flags) {
    return (flags&O_CREAT) || ((flags&O_TMPFILE)==O_TMPFILE);
}
static FILE *cache_fopen(const char *value,const char *mode) {
    char out[4096]; return previous_fopen(path(value,out),mode);
}
static int cache_open(const char *value,int flags,...) {
    char out[4096]; const char *translated=path(value,out);
    if(!has_mode(flags)) return previous_open(translated,flags);
    va_list args; va_start(args,flags); int mode=va_arg(args,int); va_end(args);
    return previous_open(translated,flags,mode);
}
static int cache_open2(const char *value,int flags) {
    char out[4096]; return previous_open2(path(value,out),flags);
}
static int cache_openat(int dirfd,const char *value,int flags,...) {
    char out[4096]; const char *translated=path(value,out,dirfd);
    if(!has_mode(flags)) return previous_openat(dirfd,translated,flags);
    va_list args; va_start(args,flags); int mode=va_arg(args,int); va_end(args);
    return previous_openat(dirfd,translated,flags,mode);
}
static int cache_stat(const char *value,struct stat *st) {
    char out[4096]; return previous_stat(path(value,out),st);
}
static DIR *cache_opendir(const char *value) {
    char out[4096]; return previous_opendir(path(value,out));
}
static int cache_mkdir(const char *value,mode_t mode) {
    char out[4096]; return previous_mkdir(path(value,out),mode);
}
static int cache_rename(const char *from,const char *to) {
    char first[4096],second[4096]; return previous_rename(path(from,first),path(to,second));
}
static int cache_unlink(const char *value) {
    char out[4096]; return previous_unlink(path(value,out));
}
static int cache_unlinkat(int dirfd,const char *value,int flags) {
    char out[4096]; return previous_unlinkat(dirfd,path(value,out,dirfd),flags);
}
static void fork_prepare() { pthread_mutex_lock(&ldmenu_loader_trial::lock); }
static void fork_resume() { pthread_mutex_unlock(&ldmenu_loader_trial::lock); }
static bool payload_soname(int fd) {
    return ldmenu_soname_trial::replace(fd,"libktools.so","libnative.so");
}
static bool cached_payload(const char *value) {
    return value && ldmenu_trial::target(value) && strstr(value,"/cache/tmp/ktools_loader/library_");
}
static void *cache_dlopen(const char *value,int flags) {
    char out[4096]; const char *translated=path(value,out);
    if(!cached_payload(value)) return previous_dlopen(translated,flags);
    bool created=false;
    int copy=ldmenu_loader_trial::capture_file(translated,&created,-1,payload_soname);
    if(copy<0) {audit("payload-snapshot",false);return previous_dlopen(translated,flags);}
    char indirect[64]; snprintf(indirect,sizeof(indirect),"/proc/self/fd/%d",copy);
    void *handle=previous_dlopen(indirect,flags);
    audit("payload-load",handle!=nullptr);
    return handle ? handle : previous_dlopen(translated,flags);
}
template<typename F> static bool hook(void *base,const char *name,F replacement,F &previous) {
    uintptr_t old=0;
    bool result=ldmenu_arm_trial::replace_import(base,name,reinterpret_cast<uintptr_t>(replacement),&old);
    previous=reinterpret_cast<F>(old); return result;
}
static bool install_cache_hooks(void *base) {
    // Partial installation delegates unchanged paths; migration runs only if all pass.
    bool ok=true;
    ok=hook(base,"fopen",cache_fopen,previous_fopen)&&ok;
    ok=hook(base,"open",cache_open,previous_open)&&ok;
    ok=hook(base,"__open_2",cache_open2,previous_open2)&&ok;
    ok=hook(base,"openat",cache_openat,previous_openat)&&ok;
    ok=hook(base,"stat",cache_stat,previous_stat)&&ok;
    ok=hook(base,"opendir",cache_opendir,previous_opendir)&&ok;
    ok=hook(base,"mkdir",cache_mkdir,previous_mkdir)&&ok;
    ok=hook(base,"rename",cache_rename,previous_rename)&&ok;
    ok=hook(base,"unlink",cache_unlink,previous_unlink)&&ok;
    ok=hook(base,"unlinkat",cache_unlinkat,previous_unlinkat)&&ok;
    return ok;
}
static int original_snapshot() {
    size_t size=ldmenu_embedded_end-ldmenu_embedded_start;
    if(size!=3328520) return -1;
    int fd=static_cast<int>(syscall(__NR_memfd_create,"jit-cache",MFD_CLOEXEC|MFD_ALLOW_SEALING));
    if(fd<0) return -1;
    for(size_t done=0;done<size;) {
        ssize_t written=write(fd,ldmenu_embedded_start+done,size-done);
        if(written<0 && errno==EINTR) continue;
        if(written<=0) {close(fd);return -1;} done+=written;
    }
    if(!ldmenu_soname_trial::replace(fd,"libLoaderZygisk.so","libNativeBridge.so") ||
       fcntl(fd,F_ADD_SEALS,F_SEAL_WRITE|F_SEAL_GROW|F_SEAL_SHRINK|F_SEAL_SEAL)) {
        close(fd);return -1;
    }
    return fd;
}
extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm,void *reserved) {
    original_fd=original_snapshot();
    if(original_fd<0) {audit("original-snapshot",false);return JNI_ERR;}
    char indirect[64]; snprintf(indirect,sizeof(indirect),"/proc/self/fd/%d",original_fd);
    original_handle=dlopen(indirect,RTLD_NOW|RTLD_LOCAL);
    if(!original_handle) {audit("original-load",false);close(original_fd);original_fd=-1;return JNI_ERR;}
    auto entry=reinterpret_cast<jint (*)(JavaVM *,void *)>(dlsym(original_handle,"JNI_OnLoad"));
    if(!entry) {audit("entry",false);return JNI_ERR;}
    Dl_info info{}; bool patched=false;
    if(dladdr(reinterpret_cast<void *>(entry),&info) && pthread_atfork(fork_prepare,fork_resume,fork_resume)==0) {
        patched=hook(info.dli_fbase,"dlopen",cache_dlopen,previous_dlopen);
        if(patched && install_cache_hooks(info.dli_fbase)) cache_ready=ldmenu_cache_trial::migrate();
    }
    audit("dlopen-hook",patched); audit("cache-ready",cache_ready);
    return entry(vm,reserved);
}
