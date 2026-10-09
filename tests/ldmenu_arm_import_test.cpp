#include "ldmenu_arm_import.hpp"
#include <cassert>
#include <cstdio>
#include <initializer_list>
using namespace ldmenu_arm_trial;
int main() {
    const size_t page=static_cast<size_t>(sysconf(_SC_PAGESIZE));
    assert(page>=4096);
    auto *memory=static_cast<unsigned char *>(mmap(nullptr,page,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0));
    assert(memory!=MAP_FAILED);
    auto *header=reinterpret_cast<Elf64_Ehdr *>(memory);
    memcpy(header->e_ident,ELFMAG,SELFMAG);
    header->e_ident[EI_CLASS]=ELFCLASS64;header->e_ident[EI_DATA]=ELFDATA2LSB;
    header->e_type=ET_DYN;header->e_machine=EM_AARCH64;
    header->e_phoff=64;header->e_phnum=3;header->e_phentsize=sizeof(Elf64_Phdr);
    auto *ph=reinterpret_cast<Elf64_Phdr *>(memory+64);
    ph[0].p_type=PT_LOAD;ph[0].p_memsz=page;ph[0].p_flags=PF_R|PF_W;
    ph[1].p_type=PT_DYNAMIC;ph[1].p_vaddr=0x100;ph[1].p_memsz=8*sizeof(Elf64_Dyn);
    ph[2].p_type=PT_GNU_RELRO;ph[2].p_vaddr=0x300;ph[2].p_memsz=0x100;
    auto *dyn=reinterpret_cast<Elf64_Dyn *>(memory+0x100);
    dyn[0].d_tag=DT_JMPREL;dyn[0].d_un.d_ptr=0x300;
    dyn[1].d_tag=DT_PLTRELSZ;dyn[1].d_un.d_val=sizeof(Elf64_Rela);
    dyn[2].d_tag=DT_PLTREL;dyn[2].d_un.d_val=DT_RELA;
    dyn[3].d_tag=DT_SYMTAB;dyn[3].d_un.d_ptr=0x200;
    dyn[4].d_tag=DT_STRTAB;dyn[4].d_un.d_ptr=0x280;
    dyn[5].d_tag=DT_STRSZ;dyn[5].d_un.d_val=8;
    dyn[6].d_tag=DT_SYMENT;dyn[6].d_un.d_val=sizeof(Elf64_Sym);
    auto *symbols=reinterpret_cast<Elf64_Sym *>(memory+0x200);symbols[1].st_name=1;
    memcpy(memory+0x280,"\0dlopen\0",8);
    auto *rel=reinterpret_cast<Elf64_Rela *>(memory+0x300);
    rel->r_info=ELF64_R_INFO(1,R_AARCH64_JUMP_SLOT);rel->r_offset=0x380;
    auto *slot=reinterpret_cast<uintptr_t *>(memory+0x380);*slot=0x1234;
    Image image{};assert(image.init(memory));
    assert(image.import_slot("dlopen")==slot && image.import_slot("mmap")==nullptr);
    puts("PASS bounded exact ARM import; other symbols untouched");
    for(unsigned i:{0U,3U,4U})dyn[i].d_un.d_ptr+=reinterpret_cast<uintptr_t>(memory);
    assert(image.import_slot("dlopen")==slot);
    for(unsigned i:{0U,3U,4U})dyn[i].d_un.d_ptr-=reinterpret_cast<uintptr_t>(memory);
    puts("PASS relative and relocated dynamic pointers");
    header->e_machine=EM_X86_64;assert(!image.init(memory));header->e_machine=EM_AARCH64;
    header->e_phnum=33;assert(!image.init(memory));header->e_phnum=3;
    assert(image.init(memory));puts("PASS wrong architecture/header bounds rejected");
    rel->r_info=ELF64_R_INFO(65537,R_AARCH64_JUMP_SLOT);assert(!image.import_slot("dlopen"));
    rel->r_info=ELF64_R_INFO(1,R_AARCH64_JUMP_SLOT);
    symbols[1].st_name=8;assert(!image.import_slot("dlopen"));symbols[1].st_name=1;
    rel->r_offset=page+8;assert(!image.import_slot("dlopen"));rel->r_offset=0x380;
    puts("PASS malformed symbols/strings/GOT bounds rejected");
    rel[1]=rel[0];dyn[1].d_un.d_val=2*sizeof(Elf64_Rela);
    assert(!image.import_slot("dlopen"));dyn[1].d_un.d_val=sizeof(Elf64_Rela);
    dyn[2].d_un.d_val=DT_REL;assert(!image.import_slot("dlopen"));dyn[2].d_un.d_val=DT_RELA;
    dyn[7].d_tag=DT_DEBUG;assert(!image.import_slot("dlopen"));dyn[7].d_tag=DT_NULL;
    puts("PASS ambiguous import/unsupported reloc/unterminated dynamic rejected");
    ph[0].p_flags|=PF_X;uintptr_t saved=0;
    assert(!replace_import(memory,"dlopen",0x5678,&saved) && *slot==0x1234);
    ph[0].p_flags&=~PF_X;puts("PASS executable page is never made writable");
    *slot=0;assert(!replace_import(memory,"dlopen",0x5678,&saved));*slot=0x1234;
    assert(replace_import(memory,"dlopen",0x5678,&saved) && saved==0x1234 && *slot==0x5678);
    puts("PASS original preserved and exact import replaced with RELRO restored");
    assert(mprotect(memory,page,PROT_READ|PROT_WRITE)==0);
    assert(munmap(memory,page)==0);
    puts("PASS fixture cleanup; no real module/game changed");
}
