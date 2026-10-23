#!/system/bin/sh
# Sourced by app.sh. One private, on-demand matcher; shell builtins do IPC.
CACHE_PID=""
CACHE_DIR=""
CACHE_FDS=0
CACHE_RESULT=""

cache_worker_alive() {
    local pid comm state parent ignored
    [ -n "$CACHE_PID" ] || return 1
    IFS=' ' read -r pid comm state parent ignored 2>/dev/null < "/proc/$CACHE_PID/stat" || return 1
    [ "$parent" = "$$" ] || return 1
    case "$state" in Z|X|x|T|t|'') return 1 ;; esac
    return 0
}

cache_stop_worker() {
    CACHE_RESULT=""
    if [ "$CACHE_FDS" = 1 ]; then exec 6>&- 7<&-; CACHE_FDS=0; fi
    if [ -n "$CACHE_PID" ]; then
        # Only signal our own unreaped child, never an unrelated recycled PID.
        local pid comm state parent ignored
        if IFS=' ' read -r pid comm state parent ignored 2>/dev/null < "/proc/$CACHE_PID/stat" && [ "$parent" = "$$" ]; then
            kill -KILL "$CACHE_PID" 2>/dev/null
            wait "$CACHE_PID" 2>/dev/null
        fi
    fi
    CACHE_PID=""
    case "$CACHE_DIR" in
        /data/local/tmp/ldlogin-cache.*)
            rm -f "$CACHE_DIR/requests" "$CACHE_DIR/results" 2>/dev/null
            rmdir "$CACHE_DIR" 2>/dev/null
            ;;
    esac
    CACHE_DIR=""
    return 0
}

cache_start_worker() {
    cache_stop_worker
    CACHE_DIR=$(mktemp -d /data/local/tmp/ldlogin-cache.XXXXXX 2>/dev/null) || return 1
    mkfifo -m 600 "$CACHE_DIR/requests" "$CACHE_DIR/results" 2>/dev/null || { cache_stop_worker; return 1; }
    exec 6<>"$CACHE_DIR/requests" 7<>"$CACHE_DIR/results" || { cache_stop_worker; return 1; }
    CACHE_FDS=1
    (exec "$FINDER_V2" --batch-worker "$IMAGES_DIR" "$$" 6>&- 7<&- 8<&- 9>&- <"$CACHE_DIR/requests" >"$CACHE_DIR/results" 2>/dev/null) &
    CACHE_PID=$!
    local ready
    if ! IFS= read -r -t 3 ready <&7 || [ "$ready" != CACHE_READY ] || ! cache_worker_alive; then
        cache_stop_worker; return 1
    fi
    return 0
}

cache_login_scan() {
    CACHE_RESULT=""
    cache_worker_alive || cache_start_worker || return 1
    if ! printf 'LOGIN\n' >&6 || ! IFS= read -r -t 8 CACHE_RESULT <&7 || ! cache_worker_alive; then
        # Discard timed-out frames before falling back; never reuse an old result.
        cache_stop_worker; return 1
    fi
    case "$CACHE_RESULT" in
        'FOUND LOGIN '*|'FOUND CONFIRM '*|'FOUND OK '*|'NOT_FOUND '*) return 0 ;;
        *) cache_stop_worker; return 1 ;;
    esac
}
