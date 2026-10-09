#!/system/bin/sh
# One user-requested workflow only; no background monitor or root grant to game.
[ "$(id -u)" = 0 ] || exit 10
PKG=com.vng.playtogether
bounded() { /data/adb/magisk/busybox timeout -s TERM -k 1 4 "$@"; }
uptime_seconds() { IFS=' .' read -r LAUNCH_TICK LAUNCH_REST < /proc/uptime; printf '%s\n' "$LAUNCH_TICK"; }
ACT=$(bounded cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$PKG" 2>/dev/null | tail -n 1)
case "$ACT" in com.vng.playtogether/*) ;; *) exit 11 ;; esac
case "$ACT" in *[!A-Za-z0-9_./$]*|com.vng.playtogether/) exit 11 ;; esac

inspect_game() {
    PIDS=$(pidof "$PKG" 2>/dev/null); GAME_PID=${PIDS%% *}
    case "$GAME_PID" in *[!0-9]*) printf 'unknown\n'; return ;; esac
    DUMP=$(bounded dumpsys activity activities 2>/dev/null) || { printf 'unknown\n'; return; }
    [ -n "$DUMP" ] || { printf 'unknown\n'; return; }
    GAME_BLOCK=0; BLOCK_APP=0; BLOCK_HEALTHY=0; ATTACHED=0; STARTING=0; FRONT=0
    while IFS= read -r LINE; do
        case "$LINE" in
            *'* Hist #'*': ActivityRecord{'*)
                GAME_BLOCK=0; BLOCK_APP=0; BLOCK_HEALTHY=0
                case "$LINE" in *" u0 $PKG/"*) GAME_BLOCK=1 ;; esac ;;
        esac
        if [ "$GAME_BLOCK" = 1 ]; then
            case "$LINE" in
                *"app=ProcessRecord{"*" $GAME_PID:$PKG/"*) [ -n "$GAME_PID" ] && BLOCK_APP=1 ;;
                *'state=INITIALIZING '*) STARTING=1 ;;
                *'state=RESUMED '*|*'state=PAUSED '*|*'state=PAUSING '*|*'state=STOPPED '*|*'state=STOPPING '*) BLOCK_HEALTHY=1 ;;
            esac
            [ "$BLOCK_APP:$BLOCK_HEALTHY" != 1:1 ] || ATTACHED=1
        fi
        case "$LINE" in *'ResumedActivity:'*" u0 $PKG/"*) FRONT=1 ;; esac
    done <<EOF
$DUMP
EOF
    CURRENT_PIDS=$(pidof "$PKG" 2>/dev/null)
    [ "${CURRENT_PIDS%% *}" = "$GAME_PID" ] || { printf 'unknown\n'; return; }
    if [ "$ATTACHED:$FRONT" = 1:1 ]; then printf 'ready:%s\n' "$GAME_PID"
    elif [ "$ATTACHED" = 1 ]; then printf 'running:%s\n' "$GAME_PID"
    elif [ "$STARTING" = 1 ]; then printf 'starting\n'
    elif [ -z "$GAME_PID" ]; then printf 'absent\n'
    else printf 'unknown\n'; fi
}
send_start() {
    OUTPUT=$(bounded am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "$ACT" 2>&1)
    STATUS=$?
    case "$OUTPUT" in *Error:*|*Exception*|*Permission\ Denial*) STATUS=1 ;; esac
    [ "$STATUS" = 0 ]
}
wait_for_game() {
    DEADLINE=$(($(uptime_seconds) + 20)); LAST_READY=''; SAW_RUNNING=0
    while [ "$(uptime_seconds)" -lt "$DEADLINE" ]; do
        OBS=$(inspect_game)
        case "$OBS" in
            ready:*)
                [ "$LAST_READY" != "$OBS" ] || return 0
                LAST_READY=$OBS; SAW_RUNNING=1 ;;
            running:*) LAST_READY=''; SAW_RUNNING=1 ;;
            *) LAST_READY='' ;;
        esac
        sleep 2
    done
    [ "$SAW_RUNNING" = 0 ] || return 2
    return 1
}

# Never stop a game observed attached/running during this click, even if focus fails.
PROTECT_RUNNING=0; ATTEMPT=1
while [ "$ATTEMPT" -le 3 ]; do
    OBS=$(inspect_game)
    case "$OBS" in
        ready:*|running:*) PROTECT_RUNNING=1 ;;
        starting|absent)
            if [ "$PROTECT_RUNNING" = 0 ] && { [ "$ATTEMPT" -gt 1 ] || [ "$OBS" = starting ]; }; then
                # Re-check immediately before recovery; unknown/healthy state is not killed.
                CHECK=$(inspect_game)
                case "$CHECK" in
                    ready:*|running:*) PROTECT_RUNNING=1 ;;
                    starting|absent) bounded am force-stop "$PKG" >/dev/null 2>&1 || exit 13; sleep 1 ;;
                esac
            fi ;;
    esac
    send_start
    wait_for_game; RESULT=$?
    if [ "$RESULT" = 0 ]; then printf '%s\n' LDLOGIN_GAME_READY; exit 0; fi
    [ "$RESULT" != 2 ] || PROTECT_RUNNING=1
    ATTEMPT=$((ATTEMPT + 1))
done
exit 13
