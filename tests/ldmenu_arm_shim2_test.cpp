#include "ldmenu_arm_shim2.cpp"
#include <cassert>
#include <cstdlib>
#include <vector>

static char called_path[4096]; static int called_flags,called_mode;
static int mock_open(const char *value,int flags,...) {
    snprintf(called_path,sizeof(called_path),"%s",value); called_flags=flags;called_mode=-1;
    if(has_mode(flags)) {va_list args;va_start(args,flags);called_mode=va_arg(args,int);va_end(args);}
    return 92;
}
static int mock_openat(int dirfd,const char *value,int flags,...) {
    assert(dirfd==AT_FDCWD);
    snprintf(called_path,sizeof(called_path),"%s",value);called_flags=flags;called_mode=-1;
    if(has_mode(flags)) {va_list args;va_start(args,flags);called_mode=va_arg(args,int);va_end(args);}
    return 93;
}
static bool loader_name(int fd) {
    return ldmenu_soname_trial::replace(fd,"libLoaderZygisk.so","libNativeBridge.so");
}
static bool failed_transform(int) { return false; }
static void verify_copy(int source,int copy,const char *old,const char *replacement) {
    struct stat before{},after{};assert(!fstat(source,&before)&&!fstat(copy,&after));
    assert(before.st_size==after.st_size);
    std::vector<unsigned char> original(before.st_size),changed(before.st_size);
    assert(pread(source,original.data(),original.size(),0)==before.st_size);
    assert(pread(copy,changed.data(),changed.size(),0)==before.st_size);
    size_t start=original.size();
    for(size_t i=0;i+strlen(old)<original.size();++i)
        if(!memcmp(original.data()+i,old,strlen(old)+1)) {start=i;break;}
    assert(start<original.size());
    assert(!memcmp(changed.data()+start,replacement,strlen(replacement)+1));
    for(size_t i=0;i<original.size();++i)
        if(i<start || i>=start+strlen(old)+1) assert(original[i]==changed[i]);
    assert(fcntl(copy,F_GET_SEALS)&F_SEAL_WRITE);
}
int main(int argc,char **argv) {
    assert(argc==3); // host copies of original ARM loader + encrypted runtime
    char translated[4096];
    const char *legacy="/data/data/com.vng.playtogether/cache/tmp/ktools_loader/library_fixture.so";
    assert(!strcmp(ldmenu_cache_trial::translate(legacy,translated,true),
        "/data/data/com.vng.playtogether/cache/tmp/.runtime/library_fixture.so"));
    const char *alias="/data/user/0/com.vng.playtogether/cache/tmp/ktools_loader";
    assert(!strcmp(ldmenu_cache_trial::translate(alias,translated,true),
        "/data/user/0/com.vng.playtogether/cache/tmp/.runtime"));
    assert(ldmenu_cache_trial::translate(legacy,translated,false)==legacy);
    const char *outside[]={"/data/data/other/cache/tmp/ktools_loader",
        "/data/data/com.vng.playtogether/cache/tmp/ktools_loader_backup/a",
        "/data/data/com.vng.playtogether/cache/tmp/ktools_loader/../unrelated",
        "/data/data/com.vng.playtogether/cache/tmp/ktools_loader/./x",
        "/data/data/com.vng.playtogether/cache/tmp/ktools_loader//x",
        "ktools_loader","loader_meta.json"};
    for(auto value:outside) assert(ldmenu_cache_trial::translate(value,translated,true)==value);
    assert(!ldmenu_cache_trial::translate(nullptr,translated,true));
    std::vector<char> long_path(4097,'x');long_path.back()=0;
    assert(ldmenu_cache_trial::translate(long_path.data(),translated,true)==long_path.data());
    puts("PASS exact cache prefix/aliases; unrelated, traversal and oversized paths unchanged");

    char folder[]="/data/local/tmp/ldmenu-cache-fixture-XXXXXX";assert(mkdtemp(folder));
    int parent=open(folder,O_RDONLY|O_DIRECTORY|O_CLOEXEC);assert(parent>=0);
    assert(!mkdirat(parent,"ktools_loader",0700));
    int old=openat(parent,"ktools_loader",O_RDONLY|O_DIRECTORY|O_CLOEXEC);assert(old>=0);
    int file=openat(old,"loader_meta.json",O_CREAT|O_EXCL|O_WRONLY|O_CLOEXEC,0600);assert(file>=0);
    const char sample[]="fixture-only-metadata";assert(write(file,sample,sizeof(sample))==sizeof(sample));
    struct stat identity{};assert(!fstat(file,&identity));close(file);close(old);
    assert(ldmenu_cache_trial::migrate_at(parent));
    assert(ldmenu_cache_trial::restore_at(parent,getuid()));
    assert(ldmenu_cache_trial::migrate_at(parent));
    struct stat check{};assert(fstatat(parent,"ktools_loader",&check,AT_SYMLINK_NOFOLLOW)==-1 && errno==ENOENT);
    int current=openat(parent,".runtime",O_RDONLY|O_DIRECTORY|O_CLOEXEC);assert(current>=0);
    int preserved=openat(current,"loader_meta.json",O_RDONLY|O_CLOEXEC);assert(preserved>=0);
    assert(!fstat(preserved,&check) && check.st_ino==identity.st_ino && check.st_size==identity.st_size &&
           check.st_uid==identity.st_uid && check.st_mode==identity.st_mode &&
           check.st_mtim.tv_sec==identity.st_mtim.tv_sec && check.st_mtim.tv_nsec==identity.st_mtim.tv_nsec);
    char sample_copy[sizeof(sample)];assert(read(preserved,sample_copy,sizeof(sample_copy))==sizeof(sample_copy));
    assert(!memcmp(sample,sample_copy,sizeof(sample)));close(preserved);
    assert(ldmenu_cache_trial::migrate_at(parent));
    puts("PASS atomic cache migration preserves metadata bytes, inode, ownership, mode and mtime; repeat safe");
    assert(!mkdirat(parent,"ktools_loader",0700));assert(!ldmenu_cache_trial::migrate_at(parent));
    assert(!ldmenu_cache_trial::restore_at(parent,getuid()));
    assert(!unlinkat(parent,"ktools_loader",AT_REMOVEDIR));
    assert(!symlinkat("/does/not/exist",parent,"ktools_loader"));assert(!ldmenu_cache_trial::migrate_at(parent));
    assert(!unlinkat(parent,"ktools_loader",0));
    assert(!unlinkat(current,"loader_meta.json",0));close(current);
    assert(!unlinkat(parent,".runtime",AT_REMOVEDIR));
    assert(!symlinkat("/does/not/exist",parent,".runtime"));assert(!ldmenu_cache_trial::migrate_at(parent));
    assert(!unlinkat(parent,".runtime",0));
    assert(ldmenu_cache_trial::migrate_at(parent));assert(!unlinkat(parent,".runtime",AT_REMOVEDIR));
    close(parent);assert(!rmdir(folder));
    puts("PASS cache conflicts/symlinks refused; empty first-use cache; exact fixture cleanup");

    previous_open=mock_open;previous_openat=mock_openat;cache_ready=true;
    assert(cache_open(legacy,O_RDONLY)==92 && called_flags==O_RDONLY && called_mode==-1);
    assert(!strcmp(called_path,"/data/data/com.vng.playtogether/cache/tmp/.runtime/library_fixture.so"));
    assert(cache_open(legacy,O_CREAT|O_WRONLY,0640)==92 && called_mode==0640);
    assert(cache_openat(AT_FDCWD,legacy,O_RDONLY)==93 && called_mode==-1);
    assert(cache_openat(AT_FDCWD,legacy,O_CREAT|O_RDWR,0600)==93 && called_mode==0600);
    assert(!has_mode(O_RDONLY) && has_mode(O_TMPFILE|O_RDWR));
    cache_ready=false;assert(cache_open(legacy,O_RDONLY)==92 && !strcmp(called_path,legacy));
    puts("PASS open/openat mode argument forwarded only when present; disabled hooks delegate unchanged");

    int original=open(argv[1],O_RDONLY|O_CLOEXEC);assert(original>=0);
    int runtime=open(argv[2],O_RDONLY|O_CLOEXEC);assert(runtime>=0);
    bool created=false;
    int plain=ldmenu_loader_trial::capture_file(nullptr,&created,original);assert(plain>=0&&created);
    int normalized=ldmenu_loader_trial::capture_file(nullptr,&created,original,loader_name);assert(normalized>=0&&created&&normalized!=plain);
    verify_copy(original,normalized,"libLoaderZygisk.so","libNativeBridge.so");
    assert(ldmenu_soname_trial::matches(original,"libLoaderZygisk.so"));
    assert(ldmenu_soname_trial::matches(normalized,"libNativeBridge.so"));
    assert(!ldmenu_soname_trial::matches(normalized,"libLoaderZygisk.so"));
    assert(ldmenu_loader_trial::capture_file(nullptr,&created,original,loader_name)==normalized&&!created);
    int payload=ldmenu_loader_trial::capture_file(nullptr,&created,runtime,payload_soname);assert(payload>=0&&created);
    verify_copy(runtime,payload,"libktools.so","libnative.so");
    puts("PASS real ARM loader/runtime SONAME copies differ only at exact metadata string; sources immutable; copies sealed");
    size_t retained=ldmenu_loader_trial::total_bytes;
    assert(ldmenu_loader_trial::capture_file(nullptr,&created,runtime,failed_transform)==-1&&!created);
    assert(ldmenu_loader_trial::total_bytes==retained);
    assert(!ldmenu_soname_trial::replace(normalized,"libNativeBridge.so","too-long-new-library.so"));
    assert(!ldmenu_soname_trial::replace(normalized,"wrong-name.so","other-name.so"));
    int embedded=original_snapshot();assert(embedded>=0);verify_copy(original,embedded,"libLoaderZygisk.so","libNativeBridge.so");close(embedded);
    close(original);close(runtime);
    for(auto &item:ldmenu_loader_trial::files) if(item.fd>=0) close(item.fd);
    puts("PASS callback identity/cache reuse, transform failure/no budget growth, exact name/length refusal and embedded snapshot");
    puts("PASS six groups; no game/module/account changed");
}
