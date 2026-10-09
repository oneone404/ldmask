SKIPUNZIP=0
set_perm_recursive "$MODPATH" 0 0 0755 0644
[ -f "$MODPATH/zygisk/x86_64.so" ] && [ -f "$MODPATH/zygisk/arm64-v8a.so" ] || abort "Missing LDMenu payload"
for OLD_DIR in /data/adb/modules/ktools_zygisk /data/adb/modules_update/ktools_zygisk; do
    [ ! -L "$OLD_DIR" ] || abort "Refusing symlink legacy module"
    [ ! -e "$OLD_DIR" ] || [ -d "$OLD_DIR" ] || abort "Invalid legacy module directory"
    if [ -d "$OLD_DIR" ]; then
        [ ! -L "$OLD_DIR/module.prop" ] && [ -f "$OLD_DIR/module.prop" ] || abort "Invalid legacy module metadata"
        tr -d '\r' < "$OLD_DIR/module.prop" | grep -qx 'id=ktools_zygisk' || abort "Unexpected legacy module ID"
        for FLAG in disable remove; do
            [ ! -L "$OLD_DIR/$FLAG" ] || abort "Refusing symlink module flag"
            [ ! -e "$OLD_DIR/$FLAG" ] || [ -f "$OLD_DIR/$FLAG" ] || abort "Invalid module flag"
        done
    fi
done
for OLD_DIR in /data/adb/modules/ktools_zygisk /data/adb/modules_update/ktools_zygisk; do
    if [ -d "$OLD_DIR" ]; then
        if [ ! -f "$OLD_DIR/remove" ] && [ -f "$OLD_DIR/disable" ]; then
            touch "$MODPATH/disable" || abort "Cannot preserve disabled state"
        fi
        touch "$OLD_DIR/disable" "$OLD_DIR/remove" || abort "Cannot retire legacy module"
    fi
done
ui_print "- LDMenu installed; reboot LD to activate"
