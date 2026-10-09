#include "ldmenu_arm_import.hpp"
#include "../native/src/core/zygisk/ldmenu_fd.hpp"
#include <android/log.h>
#include <dlfcn.h>
#include <jni.h>
#include <cerrno>
#include <cstdio>

// Test-only ARM loader shim. The original module is retained byte-for-byte.
extern "C" const unsigned char ldmenu_embedded_start[],ldmenu_embedded_end[];
static void *(*original_dlopen)(const char *,int);
static void *original_handle;
static int original_fd=-1;
static unsigned audit_count;
static void audit(const char *event,bool result) {
    if(__atomic_fetch_add(&audit_count,1U,__ATOMIC_RELAXED)<8)
        __android_log_print(ANDROID_LOG_INFO,"LDMenuArmTrial","%s pid=%d result=%d",event,getpid(),result);
}
static void fork_prepare() { pthread_mutex_lock(&ldmenu_loader_trial::lock); }
static void fork_resume() { pthread_mutex_unlock(&ldmenu_loader_trial::lock); }
static bool cached_payload(const char *path) {
    return path && ldmenu_trial::target(path) &&
        strstr(path,"/cache/tmp/ktools_loader/library_")!=nullptr;
}
static void *masked_dlopen(const char *path,int flags) {
    if(!cached_payload(path)) return original_dlopen(path,flags);
    bool created=false;
    int copy=ldmenu_loader_trial::capture_file(path,&created);
    if(copy<0) { audit("snapshot",false); return original_dlopen(path,flags); }
    char indirect[64]; snprintf(indirect,sizeof(indirect),"/proc/self/fd/%d",copy);
    void *handle=original_dlopen(indirect,flags);
    audit("payload-load",handle!=nullptr);
    return handle ? handle : original_dlopen(path,flags);
}
static int original_snapshot() {
    size_t size=ldmenu_embedded_end-ldmenu_embedded_start;
    if(size!=3328520) return -1;
    int fd=static_cast<int>(syscall(__NR_memfd_create,"jit-cache",MFD_CLOEXEC|MFD_ALLOW_SEALING));
    if(fd<0) return -1;
    for(size_t done=0;done<size;) {
        ssize_t written=write(fd,ldmenu_embedded_start+done,size-done);
        if(written<0 && errno==EINTR) continue;
        if(written<=0) {close(fd);return -1;}
        done+=written;
    }
    if(fcntl(fd,F_ADD_SEALS,F_SEAL_WRITE|F_SEAL_GROW|F_SEAL_SHRINK|F_SEAL_SEAL)) {close(fd);return -1;}
    return fd;
}
extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm,void *reserved) {
    original_fd=original_snapshot();
    if(original_fd<0) {audit("original-snapshot",false);return JNI_ERR;}
    char path[64]; snprintf(path,sizeof(path),"/proc/self/fd/%d",original_fd);
    original_handle=dlopen(path,RTLD_NOW|RTLD_LOCAL);
    if(!original_handle) {audit("original-load",false);close(original_fd);original_fd=-1;return JNI_ERR;}
    auto entry=reinterpret_cast<jint (*)(JavaVM *,void *)>(dlsym(original_handle,"JNI_OnLoad"));
    if(!entry) {audit("entry",false);return JNI_ERR;}
    Dl_info info{};
    bool patched=false;
    if(dladdr(reinterpret_cast<void *>(entry),&info) &&
       pthread_atfork(fork_prepare,fork_resume,fork_resume)==0)
        patched=ldmenu_arm_trial::replace_import(info.dli_fbase,"dlopen",
                    reinterpret_cast<uintptr_t>(masked_dlopen),reinterpret_cast<uintptr_t *>(&original_dlopen));
    audit("import-hook",patched);
    // Hook failure delegates unchanged behavior; never suppress original startup.
    return entry(vm,reserved);
}
