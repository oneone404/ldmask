SKIPUNZIP=0

ui_print "**********************************************"
ui_print "*                   LDLogin                  *"
ui_print "**********************************************"
ui_print "- Installing LDLogin..."

# Phan quyen thuc thi
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/system/bin/app.sh" 0 0 0755
set_perm "$MODPATH/system/bin/ldlogin_gate.sh" 0 0 0755
set_perm "$MODPATH/system/bin/ldlogin_finder" 0 0 0755

# Tao thu muc va chep san anh mau vao /sdcard/ldlogin/images/
mkdir -p /sdcard/ldlogin/images
if [ -d "$MODPATH/images" ]; then
    cp -f "$MODPATH/images/"* /sdcard/ldlogin/images/ 2>/dev/null
fi

# Leave the currently running module intact. Magisk activates staged updates at boot.
# User settings live outside the module and must NEVER be overwritten by flashing.
[ ! -L /data/adb/ldlogin ] || abort "LDLogin settings directory must not be a symlink"
mkdir -p /data/adb/ldlogin
chmod 700 /data/adb/ldlogin

. "$MODPATH/migrate.sh"

ui_print " "
ui_print "[SUCCESS] Module LDLogin installed successfully!"
ui_print "[ACCOUNT] Shared Pictures/Acc.csv + LD-map.txt"
ui_print "[SETTINGS] LDLogin Launcher /data/adb/ldlogin/settings.json"
ui_print "[DEFAULT] Bot OFF, boot wait 30s, logging OFF"
ui_print "[LOG] File log: /sdcard/ldlogin/log.log"
ui_print "[IMAGES] Thu muc anh: /sdcard/ldlogin/images/"
ui_print "[REBOOT] Vui long khoi dong lai LDPlayer de kich hoat!"
