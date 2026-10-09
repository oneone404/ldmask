#!/system/bin/sh
# Event-driven gate. Sourced by app.sh; this file never launches/taps the game.
BOT_RUN_ALLOWED=0
GATE_OFF_SEQUENCE=0
GATE_WATCH_PID=""
GATE_WATCH_PATH=""
GATE_READY=0
GATE_RUNTIME_DIR=""
GATE_SEQUENCE=0
GATE_LAST_SEEN=0
GATE_FD_OPEN=0
GATE_PROTOCOL_BAD=0

gate_clock() {
    local uptime ignored
    if IFS=' ' read -r uptime ignored < /proc/uptime; then
        GATE_NOW=${uptime%%.*}
    else
        GATE_NOW=0
    fi
}

gate_off() {
    [ "$BOT_RUN_ALLOWED" = 1 ] && GATE_OFF_SEQUENCE=$((GATE_OFF_SEQUENCE + 1))
    BOT_RUN_ALLOWED=0
    BOT_ACTIVE=0
    ENABLE_LOG=0
}

gate_watcher_alive() {
    local pid comm state ignored
    [ -n "$GATE_WATCH_PID" ] || return 1
    kill -0 "$GATE_WATCH_PID" 2>/dev/null || return 1
    IFS=' ' read -r pid comm state ignored < "/proc/$GATE_WATCH_PID/stat" 2>/dev/null || return 1
    case "$state" in Z|X|x|T|t|'') return 1 ;; esac
    return 0
}

gate_stop_watcher() {
    gate_off
    GATE_READY=0
    if [ "$GATE_FD_OPEN" = 1 ]; then exec 8<&-; GATE_FD_OPEN=0; fi
    if [ -n "$GATE_WATCH_PID" ]; then
        kill -TERM "$GATE_WATCH_PID" 2>/dev/null
        kill -CONT "$GATE_WATCH_PID" 2>/dev/null
        kill -KILL "$GATE_WATCH_PID" 2>/dev/null
        wait "$GATE_WATCH_PID" 2>/dev/null
    fi
    GATE_WATCH_PID=""
    GATE_WATCH_PATH=""
    GATE_SEQUENCE=0
    GATE_LAST_SEEN=0
    GATE_PROTOCOL_BAD=0
    case "$GATE_RUNTIME_DIR" in
        /data/local/tmp/ldlogin-gate.*)
            rm -f "$GATE_RUNTIME_DIR/events" 2>/dev/null
            rmdir "$GATE_RUNTIME_DIR" 2>/dev/null
            ;;
    esac
    GATE_RUNTIME_DIR=""
    return 0
}

# Frames contain no account data. Reject stale, malformed or foreign frames.
gate_accept_frame() {
    local token
    for token in "$GATE_MSG_PID" "$GATE_MSG_SEQ" "$GATE_MSG_TIME"; do
        case "$token" in ''|*[!0-9]*) gate_off; return 1 ;; esac
    done
    gate_clock
    if [ "$GATE_MSG_TAG" != STATE ] || [ "$GATE_MSG_PID" != "$GATE_WATCH_PID" ] ||
       [ -n "$GATE_MSG_EXTRA" ] || [ "$GATE_MSG_SEQ" -le "$GATE_SEQUENCE" ] ||
       [ "$GATE_MSG_TIME" -gt "$GATE_NOW" ] || [ $((GATE_NOW - GATE_MSG_TIME)) -gt 90 ]; then
        gate_off
        return 1
    fi
    case "$GATE_MSG_VALUE" in 0|1) ;; *) gate_off; return 1 ;; esac
    case "$GATE_MSG_LOG" in 0|1) ;; *) gate_off; return 1 ;; esac
    GATE_SEQUENCE="$GATE_MSG_SEQ"
    GATE_LAST_SEEN="$GATE_MSG_TIME"
    local previous="$BOT_RUN_ALLOWED"
    if [ "$GATE_MSG_VALUE" = 0 ]; then gate_off; else BOT_RUN_ALLOWED=1; fi
    ENABLE_LOG="$GATE_MSG_LOG"
    [ "$previous" = "$BOT_RUN_ALLOWED" ] || log_msg "[CONFIG] LDLogin enabled -> bot: $BOT_RUN_ALLOWED"
    return 0
}

gate_read_frame() {
    local timeout="$1" fd="$2"
    GATE_MSG_TAG="" GATE_MSG_PID="" GATE_MSG_SEQ="" GATE_MSG_VALUE="" GATE_MSG_TIME="" GATE_MSG_LOG="" GATE_MSG_EXTRA=""
    if IFS=' ' read -r -t "$timeout" GATE_MSG_TAG GATE_MSG_PID GATE_MSG_SEQ GATE_MSG_VALUE GATE_MSG_TIME GATE_MSG_LOG GATE_MSG_EXTRA <&"$fd"; then
        gate_accept_frame && return 0
        GATE_PROTOCOL_BAD=1
        return 1
    fi
    if [ -n "$GATE_MSG_TAG$GATE_MSG_PID$GATE_MSG_SEQ$GATE_MSG_VALUE$GATE_MSG_TIME$GATE_MSG_LOG$GATE_MSG_EXTRA" ]; then
        gate_off
        GATE_PROTOCOL_BAD=1
    fi
    return 1
}

gate_start_watcher() {
    gate_stop_watcher
    [ -x "$FINDER_V2" ] || return 1
    GATE_RUNTIME_DIR=$(mktemp -d /data/local/tmp/ldlogin-gate.XXXXXX 2>/dev/null) || return 1
    mkfifo -m 600 "$GATE_RUNTIME_DIR/events" 2>/dev/null || { gate_stop_watcher; return 1; }
    # Temporary RDWR fd prevents a blocking FIFO-open handshake.
    exec 9<>"$GATE_RUNTIME_DIR/events" || { gate_stop_watcher; return 1; }
    (exec "$FINDER_V2" --watch-config "$GATE_PATH" "$$" 8<&- 9>&- >"$GATE_RUNTIME_DIR/events" 2>/dev/null) &
    GATE_WATCH_PID=$!
    if ! gate_read_frame 3 9; then
        exec 9>&-
        gate_stop_watcher
        return 1
    fi
    exec 8<"$GATE_RUNTIME_DIR/events"
    GATE_FD_OPEN=1
    exec 9>&-
    GATE_WATCH_PATH="$GATE_PATH"
    GATE_READY=1
    log_msg "[CONFIG] inotify watcher PID=$GATE_WATCH_PID, file=$GATE_WATCH_PATH"
    return 0
}

reload_bot_gate() {
    GATE_PATH="/data/adb/ldlogin/settings.json"
    if [ "$GATE_READY" != 1 ] || [ "$GATE_WATCH_PATH" != "$GATE_PATH" ] || ! gate_watcher_alive; then
        gate_start_watcher || { gate_off; return 0; }
    fi
    local count=0
    while gate_read_frame 0.01 8; do
        count=$((count + 1))
        if [ "$count" -ge 64 ]; then gate_stop_watcher; return 0; fi
    done
    gate_clock
    if [ "$GATE_PROTOCOL_BAD" = 1 ] || ! gate_watcher_alive || [ $((GATE_NOW - GATE_LAST_SEEN)) -gt 90 ]; then
        gate_stop_watcher
    fi
    return 0
}

# Builtin read replaces sleep: a saved OFF/ON event wakes the shell immediately.
wait_bot_gate() {
    local timeout="$1"
    if [ "$GATE_READY" != 1 ] || ! gate_watcher_alive; then
        gate_off
        sleep 5
        return 1
    fi
    if gate_read_frame "$timeout" 8; then
        return 0
    fi
    gate_clock
    if [ "$GATE_PROTOCOL_BAD" = 1 ] || ! gate_watcher_alive || [ $((GATE_NOW - GATE_LAST_SEEN)) -gt 90 ]; then
        gate_stop_watcher
    fi
    return 0
}
