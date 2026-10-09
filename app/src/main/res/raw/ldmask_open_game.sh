#!/system/bin/sh
# Root starts an existing launcher activity; it does not grant root to the game.
[ "$(id -u)" = 0 ] || exit 10
PKG=com.vng.playtogether
ACT=$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$PKG" 2>/dev/null | tail -n 1)
case "$ACT" in com.vng.playtogether/*) ;; *) exit 11 ;; esac
case "$ACT" in *[!A-Za-z0-9_./$]*|com.vng.playtogether/) exit 11 ;; esac
# Exactly one launch, no force-stop/restart and no overlapping monkey requests.
OUTPUT=$(am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "$ACT" 2>&1)
STATUS=$?
[ "$STATUS" = 0 ] || exit 13
case "$OUTPUT" in *Error:*|*Exception*|*Permission\ Denial*) exit 13 ;; esac
printf '%s\n' LDLOGIN_LAUNCH_SENT
