#include "../native/src/core/zygisk/ldmenu_trace.hpp"
#include <cassert>
#include <cstdarg>
#include <cstdio>

static long captured[7];
static unsigned events = 0;
static long mock(long number, ...) {
    captured[0] = number;
    va_list args; va_start(args, number);
    const int count = number == __NR_ptrace ? 4 : 6;
    for (int i = 1; i <= count; ++i) captured[i] = va_arg(args, long);
    va_end(args);
    return 713;
}
static void observe(unsigned long before, unsigned long after, long result) {
    assert((before & ~static_cast<unsigned long>(PTRACE_O_EXITKILL)) == after);
    assert(result == 713);
    ++events;
}
int main() {
    using ldmenu_trace_trial::options;
    constexpr long app = 741;
    unsigned long flags = PTRACE_O_EXITKILL | PTRACE_O_TRACESYSGOOD | PTRACE_O_TRACECLONE;
    assert(options(PTRACE_SETOPTIONS, app, app, flags) ==
           (flags & ~static_cast<unsigned long>(PTRACE_O_EXITKILL)));
    assert(options(PTRACE_SETOPTIONS, app + 1, app, flags) == flags);
    assert(options(PTRACE_SETOPTIONS, 0, 0, flags) == flags);
    assert(options(PTRACE_CONT, app, app, flags) == flags);
    assert(options(PTRACE_SETOPTIONS, app, app, 0) == 0);
    assert(options(PTRACE_SEIZE, app, app, flags) ==
           (flags & ~static_cast<unsigned long>(PTRACE_O_EXITKILL)));
    puts("PASS exact target/request; all other options preserved");
#if defined(__x86_64__)
    ldmenu_trace_previous_syscall = mock;
    ldmenu_trace_app_pid = app;
    ldmenu_trace_options_observer = observe;
    assert(ldmenu_trace_syscall(1000L, 11L, 12L, 13L, 14L, 15L, 16L) == 713);
    for (int i = 1; i <= 6; ++i) assert(captured[i] == 10 + i);
    assert(events == 0);
    puts("PASS non-ptrace tail-call preserves all six argument slots");
    assert(ldmenu_trace_syscall(static_cast<long>(__NR_ptrace),
           static_cast<long>(PTRACE_SETOPTIONS), app, 0L, static_cast<long>(flags)) == 713);
    assert(captured[0] == __NR_ptrace && captured[1] == PTRACE_SETOPTIONS &&
           captured[2] == app && captured[3] == 0 &&
           captured[4] == static_cast<long>(flags & ~static_cast<unsigned long>(PTRACE_O_EXITKILL)));
    assert(events == 1);
    puts("PASS ptrace forwarding ABI and diagnostic callback");
    assert(ldmenu_trace_syscall(static_cast<long>(__NR_ptrace),
           static_cast<long>(PTRACE_CONT), app, 0L, 17L) == 713);
    assert(captured[4] == 17 && events == 1);
    puts("PASS normal ptrace request unchanged");
#endif
}
