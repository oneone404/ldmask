#!/system/bin/sh
# Verify deletion independently of remount/timeout status. No deletion or remount here.
[ "$(id -u)" = 0 ] || exit 1
for TARGET in /system/bin/su /system/xbin/su; do
    [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ] || exit 1
done
ROOT_TMP=$(magisk --path) || exit 1
case "$ROOT_TMP" in /sbin|/debug_ramdisk|/dev/*) ;; *) exit 1 ;; esac
[ -x "$ROOT_TMP/su" ] && [ -x "$ROOT_TMP/magisk" ] || exit 1
ROOT_SU_REAL=$(readlink -f "$ROOT_TMP/su") || exit 1
case "$ROOT_SU_REAL" in /system/bin/su|/system/xbin/su) exit 1 ;; esac
"$ROOT_TMP/su" -c id >/dev/null 2>&1 || exit 1
printf '%s\n' LDMASK_SYSTEM_SU_REMOVED
