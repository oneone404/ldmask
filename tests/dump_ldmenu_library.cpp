// Read-only, bounded capture of the user's loaded LDMenu library, not game heap.
// Copies the original ELF then replaces ONLY exact-path nonwritable mappings.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cerrno>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>

static const char *source = "/data/data/com.vng.playtogether/cache/tmp/ktools_loader/library_188_806aa5dc667b701f.so";
struct Region { unsigned long long start, end, offset; };
static Region regions[32];
static unsigned count;
static unsigned long long start_time(int pid) {
    char path[64], text[2048];
    snprintf(path,sizeof(path),"/proc/%d/stat",pid);
    FILE *f=fopen(path,"r"); if (!f) return 0;
    bool ok=fgets(text,sizeof(text),f); fclose(f); if (!ok) return 0;
    char *cursor=strrchr(text,')'); if (!cursor) return 0;
    cursor+=2;
    for (unsigned field=3; field<22; ++field) {
        cursor=strchr(cursor,' '); if (!cursor) return 0; ++cursor;
    }
    return strtoull(cursor,nullptr,10);
}
static bool read_regions(int pid, Region *out, unsigned *n) {
    char path[64], line[2048]; *n=0;
    snprintf(path,sizeof(path),"/proc/%d/maps",pid);
    FILE *f=fopen(path,"r"); if (!f) return false;
    while (fgets(line,sizeof(line),f)) {
        Region r{}; char perms[5]; int used=0;
        if (sscanf(line,"%llx-%llx %4s %llx %*s %*s %n",&r.start,&r.end,perms,&r.offset,&used)!=4) continue;
        char *name=line+used; name[strcspn(name,"\r\n")]=0;
        if (strcmp(name,source)!=0 || perms[0]!='r' || perms[1]=='w') continue;
        if (*n>=32 || r.end<=r.start || r.end-r.start>16*1024*1024) { fclose(f); return false; }
        out[(*n)++]=r;
    }
    fclose(f); return *n>0;
}
static bool transfer(int from,int to,unsigned long long input,unsigned long long output,size_t size) {
    char data[8192];
    while (size) {
        size_t part=size<sizeof(data)?size:sizeof(data); ssize_t n;
        do { n=pread(from,data,part,input); } while (n<0 && errno==EINTR);
        if (n<=0) return false;
        ssize_t done=0;
        while (done<n) {
            ssize_t w=pwrite(to,data+done,n-done,output+done);
            if (w<0 && errno==EINTR) continue;
            if (w<=0) return false; done+=w;
        }
        input+=n; output+=n; size-=n;
    }
    return true;
}
int main(int argc,char **argv) {
    if (argc!=2 || getuid()!=0) return 2;
    char *end; long candidate=strtol(argv[1],&end,10);
    if (*end || candidate<2 || candidate>1000000) return 2;
    int pid=static_cast<int>(candidate);
    char path[64], command[256]{};
    snprintf(path,sizeof(path),"/proc/%d/cmdline",pid);
    int fd=open(path,O_RDONLY|O_CLOEXEC); if (fd<0) return 3;
    ssize_t length=read(fd,command,sizeof(command)-1); close(fd);
    if (length<=0 || strcmp(command,"com.vng.playtogether")) return 3;
    auto identity=start_time(pid); if (!identity || !read_regions(pid,regions,&count)) return 4;
    int original=open(source,O_RDONLY|O_CLOEXEC|O_NOFOLLOW);
    struct stat info{};
    if (original<0 || fstat(original,&info) || !S_ISREG(info.st_mode) ||
        info.st_size<64 || info.st_size>16*1024*1024) return 5;
    snprintf(path,sizeof(path),"/proc/%d/mem",pid);
    int memory=open(path,O_RDONLY|O_CLOEXEC); if (memory<0) return 6;
    char output[]="/data/local/tmp/ldmenu-ram-audit-XXXXXX";
    int artifact=mkstemp(output); if (artifact<0) return 7;
    bool ok=transfer(original,artifact,0,0,info.st_size);
    unsigned long long total=0;
    for (unsigned i=0;ok && i<count;++i) {
        const auto &r=regions[i];
        if (r.offset>=static_cast<unsigned long long>(info.st_size)) { ok=false; break; }
        auto size=r.end-r.start;
        if (size>static_cast<unsigned long long>(info.st_size)-r.offset) size=info.st_size-r.offset;
        ok=transfer(memory,artifact,r.start,r.offset,size); total+=size;
    }
    Region after[32]; unsigned after_count;
    struct stat final_info{};
    ok=ok && start_time(pid)==identity && read_regions(pid,after,&after_count) && after_count==count &&
       memcmp(regions,after,sizeof(Region)*count)==0 && fstat(original,&final_info)==0 &&
       final_info.st_size==info.st_size && final_info.st_mtime==info.st_mtime &&
       final_info.st_mtim.tv_nsec==info.st_mtim.tv_nsec;
    close(original); close(memory);
    if (ok) { fsync(artifact); fchmod(artifact,0644); }
    close(artifact);
    if (!ok) { unlink(output); puts("CAPTURE_REFUSED"); return 8; }
    printf("ARTIFACT=%s\nREGIONS=%u\nREADONLY_BYTES=%llu\n",output,count,total);
    puts("WRITABLE_RAM_NOT_CAPTURED; layout/identity checked, not an atomic frozen snapshot.");
}
