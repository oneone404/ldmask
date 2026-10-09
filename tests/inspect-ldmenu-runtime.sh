#!/system/bin/sh
set -eu
[ "$(id -u)" = 0 ]
pid=${1:?game pid required}
case "$pid" in ''|*[!0-9]*) exit 2;; esac
[ "$(tr '\000' '\n' < /proc/$pid/cmdline | head -n 1)" = com.vng.playtogether ]
grep -E '^(Name|Pid|PPid|TracerPid|Threads):' /proc/$pid/status
grep -E 'library_188|/modules/ldmenu/|memfd:jit-cache' /proc/$pid/maps || true
tracer=$(awk '/^TracerPid:/ {print $2}' /proc/$pid/status)
if [ "$tracer" -gt 0 ] && [ -f /proc/$tracer/status ]; then
    echo TRACER_METADATA
    grep -E '^(Name|Pid|PPid|TracerPid|Threads):' /proc/$tracer/status
    grep -E 'library_188|/modules/ldmenu/|memfd:jit-cache' /proc/$tracer/maps || true
    echo TRACER_KERNEL_WAIT
    cat /proc/$tracer/syscall || true
fi
if [ "${2:-capture}" != metadata ]; then
    /data/local/tmp/ldmenu-readonly-capture "$pid"
fi
