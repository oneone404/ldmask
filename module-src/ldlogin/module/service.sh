#!/system/bin/sh
MODDIR=${0%/*}
[ -z "$MODDIR" ] || [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/ldlogin"

# Read once per boot. Invalid/missing settings use OFF / 30 seconds / no logs.
BOOT_WAIT_SECONDS=30
BOOT_LOGGING=0
load_boot_settings() {
    local tag enabled seconds logging extra result
    result=$("$MODDIR/system/bin/ldlogin_finder" --settings /data/adb/ldlogin/settings.json 2>/dev/null)
    IFS=' ' read -r tag enabled seconds logging extra <<EOF
$result
EOF
    if [ "$tag" = SETTINGS ] && [ -z "$extra" ]; then
        case "$seconds" in ''|*[!0-9]*) ;; *) [ "$seconds" -le 600 ] && BOOT_WAIT_SECONDS="$seconds" ;; esac
        [ "$logging" = 1 ] && BOOT_LOGGING=1
    fi
    return 0
}

wait_for_android_boot() {
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 2
    done
    load_boot_settings
    sleep "$BOOT_WAIT_SECONDS"
}
wait_for_android_boot

# Tim file app.sh o moi vi tri co the
SCRIPT_PATH=""
if [ -f "$MODDIR/system/bin/app.sh" ]; then
    SCRIPT_PATH="$MODDIR/system/bin/app.sh"
elif [ -f "/system/bin/app.sh" ]; then
    SCRIPT_PATH="/system/bin/app.sh"
elif [ -f "/data/local/tmp/app.sh" ]; then
    SCRIPT_PATH="/data/local/tmp/app.sh"
elif [ -f "$MODDIR/system\\bin\\app.sh" ]; then
    SCRIPT_PATH="$MODDIR/system\\bin\\app.sh"
fi

# The parent exists even when settings have never been saved; watcher stays OFF.
if [ ! -L /data/adb/ldlogin ]; then
    mkdir -p /data/adb/ldlogin 2>/dev/null
    chmod 700 /data/adb/ldlogin 2>/dev/null
fi
mkdir -p /sdcard/ldlogin 2>/dev/null
if [ "$BOOT_LOGGING" = 1 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BOOT] wait=${BOOT_WAIT_SECONDS}s, script=$SCRIPT_PATH" >> /sdcard/ldlogin/log.log 2>/dev/null
fi

if [ -n "$SCRIPT_PATH" ]; then
    chmod 755 "$SCRIPT_PATH"
    sh "$SCRIPT_PATH" </dev/null >/dev/null 2>&1 &
fi
