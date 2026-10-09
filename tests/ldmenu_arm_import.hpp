#pragma once
#include <elf.h>
#include <cstdint>
#include <cstring>
#include <sys/mman.h>
#include <unistd.h>

// Bounded ELF64 ARM import lookup for the exact, already-loaded test payload.
// No instruction patches, arbitrary process scan, or writable data capture.
namespace ldmenu_arm_trial {
struct Image {
    uintptr_t base{};
    const Elf64_Phdr *ph{};
    unsigned count{};
    uintptr_t end{};
    bool init(void *address) {
        base = reinterpret_cast<uintptr_t>(address);
        auto *eh = static_cast<const Elf64_Ehdr *>(address);
        if (!address || memcmp(eh->e_ident, ELFMAG, SELFMAG) ||
            eh->e_ident[EI_CLASS] != ELFCLASS64 || eh->e_ident[EI_DATA] != ELFDATA2LSB ||
            eh->e_machine != EM_AARCH64 || eh->e_type != ET_DYN ||
            eh->e_phentsize != sizeof(Elf64_Phdr) || !eh->e_phnum || eh->e_phnum > 32 ||
            eh->e_phoff > 4096 || eh->e_phoff + eh->e_phnum * sizeof(Elf64_Phdr) > 4096)
            return false;
        ph = reinterpret_cast<const Elf64_Phdr *>(base + eh->e_phoff);
        count = eh->e_phnum;
        uintptr_t highest = 0;
        for (unsigned i=0;i<count;++i) if (ph[i].p_type == PT_LOAD) {
            if (ph[i].p_vaddr > 16*1024*1024 || ph[i].p_memsz > 16*1024*1024 ||
                ph[i].p_vaddr + ph[i].p_memsz > 16*1024*1024) return false;
            if (highest < ph[i].p_vaddr + ph[i].p_memsz) highest = ph[i].p_vaddr + ph[i].p_memsz;
        }
        if (!highest || base > UINTPTR_MAX-highest) return false;
        end = base+highest;
        return contains(base,sizeof(Elf64_Ehdr));
    }
    bool contains(uintptr_t value,size_t size) const {
        if (value < base || size > end-base || value > end-size) return false;
        for (unsigned i=0;i<count;++i) if (ph[i].p_type==PT_LOAD && (ph[i].p_flags&PF_R)) {
            auto start = base+ph[i].p_vaddr;
            auto limit = start+ph[i].p_memsz;
            if (value >= start && value <= limit && size <= limit-value) return true;
        }
        return false;
    }
    uintptr_t pointer(Elf64_Addr value,size_t size) const {
        if (contains(value,size)) return value;
        if (value > UINTPTR_MAX-base) return 0;
        return contains(base+value,size) ? base+value : 0;
    }
    int permissions(uintptr_t value) const {
        for (unsigned i=0;i<count;++i) if (ph[i].p_type==PT_LOAD &&
            value >= base+ph[i].p_vaddr && value < base+ph[i].p_vaddr+ph[i].p_memsz) {
            int perms = (ph[i].p_flags&PF_R?PROT_READ:0) |
                        (ph[i].p_flags&PF_W?PROT_WRITE:0) |
                        (ph[i].p_flags&PF_X?PROT_EXEC:0);
            for (unsigned j=0;j<count;++j) if (ph[j].p_type==PT_GNU_RELRO &&
                value >= base+ph[j].p_vaddr && value < base+ph[j].p_vaddr+ph[j].p_memsz)
                perms &= ~PROT_WRITE;
            return perms;
        }
        return 0;
    }
    uintptr_t *import_slot(const char *name) const {
        const Elf64_Dyn *dynamic = nullptr; size_t entries=0;
        for(unsigned i=0;i<count;++i) if(ph[i].p_type==PT_DYNAMIC) {
            auto ptr=pointer(ph[i].p_vaddr,ph[i].p_memsz);
            if (!ptr || ph[i].p_memsz>65536 || ph[i].p_memsz%sizeof(Elf64_Dyn)) return nullptr;
            dynamic=reinterpret_cast<const Elf64_Dyn *>(ptr); entries=ph[i].p_memsz/sizeof(Elf64_Dyn);
        }
        if (!dynamic) return nullptr;
        Elf64_Addr rel=0,sym=0,str=0; size_t relsize=0,strsize=0,symesize=0; bool rela=false,terminated=false;
        for(size_t i=0;i<entries;++i) {
            auto &entry=dynamic[i]; if(entry.d_tag==DT_NULL) {terminated=true;break;}
            switch(entry.d_tag) {
                case DT_JMPREL: rel=entry.d_un.d_ptr;break;
                case DT_PLTRELSZ: relsize=entry.d_un.d_val;break;
                case DT_PLTREL: rela=entry.d_un.d_val==DT_RELA;break;
                case DT_SYMTAB: sym=entry.d_un.d_ptr;break;
                case DT_SYMENT: symesize=entry.d_un.d_val;break;
                case DT_STRTAB: str=entry.d_un.d_ptr;break;
                case DT_STRSZ: strsize=entry.d_un.d_val;break;
            }
        }
        if (!terminated || !rela || !rel || !sym || !str || !strsize || strsize>1024*1024 ||
            symesize!=sizeof(Elf64_Sym) || !relsize || relsize>4096*sizeof(Elf64_Rela) || relsize%sizeof(Elf64_Rela)) return nullptr;
        auto relptr=pointer(rel,relsize),symptr=pointer(sym,sizeof(Elf64_Sym)),strptr=pointer(str,strsize);
        if(!relptr || !symptr || !strptr) return nullptr;
        auto *relocations=reinterpret_cast<const Elf64_Rela *>(relptr);
        uintptr_t *found=nullptr;
        for(size_t i=0;i<relsize/sizeof(Elf64_Rela);++i) {
            const auto &r=relocations[i];
            if(ELF64_R_TYPE(r.r_info)!=R_AARCH64_JUMP_SLOT) continue;
            auto index=ELF64_R_SYM(r.r_info); if(index>65536) return nullptr;
            auto symbol=symptr+index*sizeof(Elf64_Sym);
            if(!contains(symbol,sizeof(Elf64_Sym))) return nullptr;
            auto offset=reinterpret_cast<const Elf64_Sym *>(symbol)->st_name;
            if(offset>=strsize) return nullptr;
            const char *label=reinterpret_cast<const char *>(strptr+offset);
            const void *ending=memchr(label,0,strsize-offset);
            if(!ending) return nullptr;
            if(strcmp(label,name)) continue;
            auto slot=pointer(r.r_offset,sizeof(uintptr_t));
            if(!slot || slot%alignof(uintptr_t) || found) return nullptr;
            found=reinterpret_cast<uintptr_t *>(slot);
        }
        return found;
    }
};
inline bool replace_import(void *base,const char *name,uintptr_t replacement,uintptr_t *original) {
    Image image{};
    if(!replacement || !image.init(base)) return false;
    auto *slot=image.import_slot(name); if(!slot || !*slot) return false;
    auto address=reinterpret_cast<uintptr_t>(slot);
    int perms=image.permissions(address);
    long page=sysconf(_SC_PAGESIZE);
    if(page<=0 || (page&(page-1)) || !(perms&PROT_READ) || (perms&PROT_EXEC)) return false;
    auto start=address&~(static_cast<uintptr_t>(page)-1);
    if(mprotect(reinterpret_cast<void *>(start),page,PROT_READ|PROT_WRITE)) return false;
    *original=*slot;
    __atomic_store_n(slot,replacement,__ATOMIC_RELEASE);
    if(mprotect(reinterpret_cast<void *>(start),page,perms)==0) return true;
    __atomic_store_n(slot,*original,__ATOMIC_RELEASE);
    mprotect(reinterpret_cast<void *>(start),page,perms);
    return false;
}
}
