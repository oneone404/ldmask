#pragma once
#include <sys/ptrace.h>
#include <sys/syscall.h>

// Opt-in diagnostic: retain all ptrace options except EXITKILL for the exact
// selected app. This does not detach it, spoof status or prove menu usability.
namespace ldmenu_trace_trial {
inline unsigned long options(long request, long target, long app, unsigned long data) {
    if ((request == PTRACE_SETOPTIONS || request == PTRACE_SEIZE) && app > 0 && target == app)
        return data & ~static_cast<unsigned long>(PTRACE_O_EXITKILL);
    return data;
}
} // namespace ldmenu_trace_trial

#if defined(__x86_64__)
extern "C" {
__attribute__((used, visibility("hidden")))
inline long (*ldmenu_trace_previous_syscall)(long, ...) = nullptr;
__attribute__((used, visibility("hidden")))
inline long ldmenu_trace_app_pid = 0;
// Optional diagnostics callback used only for SETOPTIONS on the exact target.
inline void (*ldmenu_trace_options_observer)(unsigned long, unsigned long, long) = nullptr;

__attribute__((used, visibility("hidden")))
inline long ldmenu_trace_ptrace(long number, long request, long target,
                                void *addr, unsigned long data) {
    unsigned long filtered = ldmenu_trace_trial::options(request, target,
                                                        ldmenu_trace_app_pid, data);
    long result = ldmenu_trace_previous_syscall(number, request, target, addr, filtered);
    if ((request == PTRACE_SETOPTIONS || request == PTRACE_SEIZE) && target == ldmenu_trace_app_pid &&
        ldmenu_trace_options_observer)
        ldmenu_trace_options_observer(data, filtered, result);
    return result;
}

// Non-ptrace syscalls tail-jump without reading absent variadic arguments.
// ptrace's four actual arguments use the ordinary SysV x86_64 calling ABI.
__attribute__((naked, used, visibility("hidden")))
inline long ldmenu_trace_syscall(long, ...) {
    __asm__("cmp $101, %rdi\n\t"
            "je ldmenu_trace_ptrace\n\t"
            "jmp *ldmenu_trace_previous_syscall(%rip)\n\t");
}
}
static_assert(__NR_ptrace == 101);
#endif
