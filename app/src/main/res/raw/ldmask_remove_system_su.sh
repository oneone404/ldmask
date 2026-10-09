#!/system/bin/sh
# Fixed targets only. Never dereference their symlinks or delete directories.
set -u
[ "$(id -u)" = 0 ] || { echo '! Root required'; exit 1; }
ROOT_TMP=$(magisk --path) || exit 1
case "$ROOT_TMP" in /sbin|/debug_ramdisk|/dev/*) ;; *) echo '! Unsupported Magisk root path'; exit 1 ;; esac
[ -x "$ROOT_TMP/su" ] && [ -x "$ROOT_TMP/magisk" ] || { echo '! No independent Magisk root path'; exit 1; }
case ":${ORIGINAL_APP_PATH-}:" in
    *":$ROOT_TMP:"*) ;;
    *) echo '! Independent root is not in the app PATH; refusing cleanup to preserve root after reopening'; exit 1 ;;
esac
ROOT_SU_REAL=$(readlink -f "$ROOT_TMP/su") || exit 1
case "$ROOT_SU_REAL" in /system/bin/su|/system/xbin/su) echo '! Root depends on a target file'; exit 1 ;; esac
"$ROOT_TMP/su" -c id >/dev/null 2>&1 || { echo '! Independent Magisk su is not usable'; exit 1; }

CHANGED_MOUNT=''
restore_mount() {
    [ -n "$CHANGED_MOUNT" ] || return 0
    mount -o ro,remount "$CHANGED_MOUNT" || { echo "! Cannot restore read-only mount: $CHANGED_MOUNT"; return 1; }
    CHANGED_MOUNT=''
}
finish() {
    STATUS=$?
    trap - EXIT HUP INT TERM
    restore_mount || STATUS=1
    exit "$STATUS"
}
trap finish EXIT
trap 'exit 1' HUP INT TERM

# Preflight both entries before removing either.
for TARGET in /system/bin/su /system/xbin/su; do
    [ ! -d "$TARGET" ] || [ -L "$TARGET" ] || { echo "! Refusing directory: $TARGET"; exit 1; }
done

for TARGET in /system/bin/su /system/xbin/su; do
    if [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
        echo "- Already absent: $TARGET"
        continue
    fi
    # First try without changing mount state; Magisk may expose a writable overlay.
    if ! rm -f -- "$TARGET" 2>/dev/null; then
        MOUNT_INFO=$(awk -v target="$TARGET" '
            ($2 == "/" || index(target, $2 "/") == 1) && length($2) > length(best) {
                best=$2; opts=$4
            }
            END { if (best != "") print best " " opts }
        ' /proc/mounts)
        MOUNT_POINT=${MOUNT_INFO%% *}
        MOUNT_OPTIONS=${MOUNT_INFO#* }
        case "$MOUNT_POINT" in /|/system|/system_root|/system/bin|/system/xbin) ;; *) echo '! Unsupported system mount'; exit 1 ;; esac
        case ",$MOUNT_OPTIONS," in
            *,ro,*)
                mount -o rw,remount "$MOUNT_POINT" || { echo "! Cannot make writable: $MOUNT_POINT"; exit 1; }
                CHANGED_MOUNT=$MOUNT_POINT
                ;;
            *,rw,*) echo "! Cannot delete despite writable mount: $TARGET"; exit 1 ;;
            *) echo '! Cannot determine mount mode'; exit 1 ;;
        esac
        rm -f -- "$TARGET" || { echo "! Cannot delete: $TARGET"; exit 1; }
        restore_mount || exit 1
    fi
    [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ] || { echo "! File still exists: $TARGET"; exit 1; }
    echo "- Removed: $TARGET"
done
"$ROOT_TMP/su" -c id >/dev/null 2>&1 || { echo '! Independent root check failed'; exit 1; }
echo '- Both files absent; Magisk root preserved. No reboot performed.'
