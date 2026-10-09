#!/system/bin/sh
set -eu
id
magisk -v
magisk -V
getprop sys.boot_completed
magisk --sqlite 'SELECT key,value FROM settings WHERE key IN ("zygisk","magiskhide","sulist") ORDER BY key'
magisk magiskhide status
magisk magiskhide ls
sha256sum /system/etc/init/magisk/magisk32 /system/etc/init/magisk/magisk64 /data/adb/magisk/magisk32 /data/adb/magisk/magisk64
head -n 6 /data/adb/magisk/util_functions.sh
for module in ldmenu ldlogin; do
    if [ -f /data/adb/modules/$module/module.prop ]; then
        grep -E '^(id|name|version)=' /data/adb/modules/$module/module.prop
        [ ! -e /data/adb/modules/$module/disable ] || echo DISABLED_$module
        [ ! -e /data/adb/modules/$module/remove ] || echo REMOVAL_PENDING_$module
    fi
done
dumpsys package io.github.oneone404.ldmask | grep -E 'versionCode=|versionName='
