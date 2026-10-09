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

STATE_DIR=/data/adb/ldmask
STATE_FILE=$STATE_DIR/system-su-ro-pending
[ ! -L "$STATE_DIR" ] && [ ! -L "$STATE_FILE" ] || { echo '! Unsafe cleanup state path'; exit 1; }
mkdir -p "$STATE_DIR" && chmod 700 "$STATE_DIR" || exit 1
CHANGED_MOUNT=''
RESTORE_ERROR_LOGGED=0
mount_mode() {
    # Use the last entry for stacked mounts with the same mount point.
    awk -v point="$1" '$2 == point { opts=$4 } END { print opts }' /proc/mounts
}
restore_mount() {
    [ -n "$CHANGED_MOUNT" ] || return 0
    case ",$(mount_mode "$CHANGED_MOUNT")," in
        *,ro,*) ;;
        *)
            ERROR=$(mount -o ro,remount "$CHANGED_MOUNT" 2>&1)
            case ",$(mount_mode "$CHANGED_MOUNT")," in
                *,ro,*) ;;
                *) if [ "$RESTORE_ERROR_LOGGED" = 0 ]; then
                       echo "! Files may be removed, but cannot restore read-only mount: $CHANGED_MOUNT"
                       echo "! $ERROR"
                       echo '! Reboot LD to restore its boot mount state; do not interpret a second click as recovery.'
                       RESTORE_ERROR_LOGGED=1
                   fi
                   return 1 ;;
            esac
            ;;
    esac
    rm -f -- "$STATE_FILE" || return 1
    echo "- Read-only mount verified: $CHANGED_MOUNT"
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

# Recover a previous interrupted cleanup before considering already-absent files.
if [ -f "$STATE_FILE" ]; then
    CHANGED_MOUNT=$(cat "$STATE_FILE") || exit 1
    case "$CHANGED_MOUNT" in /|/system|/system_root|/system/bin|/system/xbin) ;;
        *) CHANGED_MOUNT=''; echo '! Invalid pending mount state'; exit 1 ;;
    esac
    echo "- Recovering pending mount: $CHANGED_MOUNT"
    restore_mount || exit 1
fi

# Preflight both entries before removing either.
for TARGET in /system/bin/su /system/xbin/su; do
    [ ! -d "$TARGET" ] || [ -L "$TARGET" ] || { echo "! Refusing directory: $TARGET"; exit 1; }
done

for TARGET in /system/bin/su /system/xbin/su; do
    REMOVED_LOGGED=0
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
            $2 == best { opts=$4
            }
            END { if (best != "") print best " " opts }
        ' /proc/mounts)
        MOUNT_POINT=${MOUNT_INFO%% *}
        MOUNT_OPTIONS=${MOUNT_INFO#* }
        case "$MOUNT_POINT" in /|/system|/system_root|/system/bin|/system/xbin) ;; *) echo '! Unsupported system mount'; exit 1 ;; esac
        case ",$MOUNT_OPTIONS," in
            *,ro,*)
                # Persist the original RO state BEFORE making the mount writable.
                # A crash/timeout or second click must not lose this obligation.
                (umask 077; printf '%s\n' "$MOUNT_POINT" > "$STATE_FILE") || exit 1
                CHANGED_MOUNT=$MOUNT_POINT
                mount -o rw,remount "$MOUNT_POINT" || { echo "! Cannot make writable: $MOUNT_POINT"; exit 1; }
                ;;
            *,rw,*) echo "! Cannot delete despite writable mount: $TARGET"; exit 1 ;;
            *) echo '! Cannot determine mount mode'; exit 1 ;;
        esac
        rm -f -- "$TARGET" || { echo "! Cannot delete: $TARGET"; exit 1; }
        echo "- Removed: $TARGET"
        REMOVED_LOGGED=1
        restore_mount || exit 1
    fi
    [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ] || { echo "! File still exists: $TARGET"; exit 1; }
    [ "$REMOVED_LOGGED" = 1 ] || echo "- Removed: $TARGET"
done
"$ROOT_TMP/su" -c id >/dev/null 2>&1 || { echo '! Independent root check failed'; exit 1; }
# Older releases did not persist a failed remount. Check the effective mount of
# both target paths even when neither file exists; do not give a misleading OK.
for TARGET in /system/bin/su /system/xbin/su; do
    OPTIONS=$(awk -v target="$TARGET" '
        ($2 == "/" || index(target, $2 "/") == 1) && length($2) >= length(best) { best=$2; opts=$4 }
        END { print opts }
    ' /proc/mounts)
    case ",$OPTIONS," in
        *,ro,*) ;;
        *) echo "! Both files absent and root preserved, but system mount is not verified read-only ($TARGET)."
           echo '! Reboot LD and check again. No further deletion is needed.'; exit 1 ;;
    esac
done
echo '- Both files absent; Magisk root preserved; system mounts verified read-only. No reboot performed.'
