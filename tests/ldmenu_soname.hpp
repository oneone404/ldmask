#pragma once
#include <elf.h>
#include <cstring>
#include <sys/stat.h>
#include <unistd.h>

// Only alter the exact same-length DT_SONAME string in a private, unsealed copy.
// Original disk bytes, symbols, instructions, offsets and payload size are kept.
namespace ldmenu_soname_trial {
inline bool replace(int fd,const char *expected,const char *replacement,bool write=true) {
    size_t count=strlen(expected)+1;
    if(count<2 || count>64 || strlen(replacement)+1!=count) return false;
    struct stat st{}; Elf64_Ehdr eh{}; Elf64_Phdr ph[32];
    if(fstat(fd,&st) || st.st_size<sizeof(eh) || st.st_size>16*1024*1024 ||
       pread(fd,&eh,sizeof(eh),0)!=sizeof(eh) || memcmp(eh.e_ident,ELFMAG,SELFMAG) ||
       eh.e_ident[EI_CLASS]!=ELFCLASS64 || eh.e_ident[EI_DATA]!=ELFDATA2LSB ||
       eh.e_machine!=EM_AARCH64 || eh.e_type!=ET_DYN ||
       eh.e_phentsize!=sizeof(Elf64_Phdr) || !eh.e_phnum || eh.e_phnum>32 ||
       eh.e_phoff>4096 || eh.e_phoff+eh.e_phnum*sizeof(Elf64_Phdr)>4096 ||
       pread(fd,ph,eh.e_phnum*sizeof(Elf64_Phdr),eh.e_phoff)!=eh.e_phnum*sizeof(Elf64_Phdr)) return false;
    const Elf64_Phdr *dynamic=nullptr;
    for(unsigned i=0;i<eh.e_phnum;++i) {
        if(ph[i].p_offset>static_cast<uint64_t>(st.st_size) ||
           ph[i].p_filesz>static_cast<uint64_t>(st.st_size)-ph[i].p_offset) return false;
        if(ph[i].p_type==PT_DYNAMIC) { if(dynamic) return false; dynamic=&ph[i]; }
    }
    if(!dynamic || !dynamic->p_filesz || dynamic->p_filesz>65536 || dynamic->p_filesz%sizeof(Elf64_Dyn)) return false;
    Elf64_Addr str=0; uint64_t size=0,name=0; bool named=false,terminated=false;
    for(uint64_t n=0;n<dynamic->p_filesz;n+=sizeof(Elf64_Dyn)) {
        Elf64_Dyn entry{};
        if(pread(fd,&entry,sizeof(entry),dynamic->p_offset+n)!=sizeof(entry)) return false;
        if(entry.d_tag==DT_NULL) {terminated=true;break;}
        if(entry.d_tag==DT_STRTAB) str=entry.d_un.d_ptr;
        if(entry.d_tag==DT_STRSZ) size=entry.d_un.d_val;
        if(entry.d_tag==DT_SONAME) {if(named) return false; named=true; name=entry.d_un.d_val;}
    }
    if(!terminated || !named || !str || !size || size>1024*1024 || name>size || count>size-name) return false;
    uint64_t offset=0; bool mapped=false;
    for(unsigned i=0;i<eh.e_phnum;++i) if(ph[i].p_type==PT_LOAD && str>=ph[i].p_vaddr &&
       str-ph[i].p_vaddr<=ph[i].p_filesz && size<=ph[i].p_filesz-(str-ph[i].p_vaddr)) {
        if(mapped) return false; mapped=true; offset=ph[i].p_offset+(str-ph[i].p_vaddr)+name;
    }
    char previous[64];
    if(!mapped || pread(fd,previous,count,offset)!=static_cast<ssize_t>(count) || memcmp(previous,expected,count)) return false;
    if(!write) return true;
    // One bounded write. Any partial write is restored before the caller refuses it.
    if(pwrite(fd,replacement,count,offset)==static_cast<ssize_t>(count)) return true;
    pwrite(fd,previous,count,offset); return false;
}
inline bool matches(int fd,const char *name) { return replace(fd,name,name,false); }
}
