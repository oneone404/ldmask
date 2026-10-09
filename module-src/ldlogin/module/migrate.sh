# Sourced by the Magisk installer. Fixed legacy paths only, no recursive deletion.
for CHECK_DIR in /data/adb/oneone /data/adb/ldlogin; do
    [ ! -L "$CHECK_DIR" ] || abort "Refusing symlink settings directory"
    [ ! -e "$CHECK_DIR" ] || [ -d "$CHECK_DIR" ] || abort "Invalid settings directory"
done
for CHECK_FILE in /data/adb/oneone/settings.json /data/adb/ldlogin/settings.json; do
    [ ! -L "$CHECK_FILE" ] || abort "Refusing symlink settings file"
    [ ! -e "$CHECK_FILE" ] || [ -f "$CHECK_FILE" ] || abort "Invalid settings file"
done
for OLD_DIR in /data/adb/modules/oneone /data/adb/modules_update/oneone; do
    [ ! -L "$OLD_DIR" ] || abort "Refusing symlink legacy module"
    [ ! -e "$OLD_DIR" ] || [ -d "$OLD_DIR" ] || abort "Invalid legacy module directory"
    if [ -d "$OLD_DIR" ]; then
        [ ! -L "$OLD_DIR/module.prop" ] && [ -f "$OLD_DIR/module.prop" ] || abort "Invalid legacy module metadata"
        tr -d '\r' < "$OLD_DIR/module.prop" | grep -qx 'id=oneone' || abort "Unexpected legacy module ID"
        for FLAG in disable remove; do
            [ ! -L "$OLD_DIR/$FLAG" ] || abort "Refusing symlink module flag"
            [ ! -e "$OLD_DIR/$FLAG" ] || [ -f "$OLD_DIR/$FLAG" ] || abort "Invalid module flag"
        done
    fi
done
mkdir -p /data/adb/ldlogin && chmod 700 /data/adb/ldlogin || abort "Cannot create settings directory"
if [ ! -e /data/adb/ldlogin/settings.json ] && [ -f /data/adb/oneone/settings.json ]; then
    mv -n /data/adb/oneone/settings.json /data/adb/ldlogin/settings.json || abort "Cannot move legacy settings"
    [ ! -e /data/adb/oneone/settings.json ] && [ -f /data/adb/ldlogin/settings.json ] || abort "Settings migration conflict"
    chmod 600 /data/adb/ldlogin/settings.json || abort "Cannot protect migrated settings"
    rmdir /data/adb/oneone 2>/dev/null || :
    ui_print "- Migrated LDLogin settings"
fi
for OLD_DIR in /data/adb/modules/oneone /data/adb/modules_update/oneone; do
    if [ -d "$OLD_DIR" ]; then
        if [ ! -f "$OLD_DIR/remove" ] && [ -f "$OLD_DIR/disable" ]; then
            touch "$MODPATH/disable" || abort "Cannot preserve disabled state"
        fi
        touch "$OLD_DIR/disable" "$OLD_DIR/remove" || abort "Cannot retire legacy module"
    fi
done
