#!/system/bin/sh
set -eu
[ "$(id -u)" = 0 ]
target=/data/adb/modules/ldmenu/zygisk/arm64-v8a.so
temp=/data/adb/modules/ldmenu/zygisk/.arm64-v8a.shim1
original=/data/adb/.ldmask-tests-20261010/ldmenu-arm-before-shim1.so
trial=/data/adb/.ldmask-tests-20261010/ldmenu-arm-shim1.so
old=ecd058d4b55c2c983152f31245285c9159c0895ee987ade5ae9438af1dcecaaf
new=4cf0e7cad0cc89848a6aa5bb5d24486a45931c20b7df9fe7aed71798b43a5069
check_sha() { value=$(sha256sum "$1") || exit 21; [ "${value%% *}" = "$2" ] || exit 22; }
[ -f "$target" ] && [ ! -L "$target" ] && [ "$(readlink -f "$target")" = "$target" ] || exit 23
[ ! -e "$temp" ] && [ ! -L "$temp" ] || exit 24
[ ! -e /data/adb/modules/ldmenu/disable ] && [ ! -e /data/adb/modules/ldmenu/remove ] || exit 25
mode=${1:?install or rollback}
case "$mode" in
 install)
  check_sha "$target" "$old"; check_sha "$trial" "$new"
  [ ! -e "$original" ] && [ ! -L "$original" ] || exit 26
  cp -p "$target" "$original"
  check_sha "$original" "$old"
  source=$trial; expected=$new ;;
 rollback)
  check_sha "$target" "$new"; check_sha "$original" "$old"
  source=$original; expected=$old ;;
 *) exit 20 ;;
esac
complete=false
cleanup() {
 if [ "$complete" != true ]; then
  cp -p "$original" "$target"
  chmod 644 "$target"
  chown 0:0 "$target"
  chcon u:object_r:system_file:s0 "$target"
 fi
 rm -f "$temp"
 sync
}
trap cleanup EXIT
cp "$source" "$temp"
chmod 644 "$temp"
chown 0:0 "$temp"
chcon u:object_r:system_file:s0 "$temp"
check_sha "$temp" "$expected"
mv "$temp" "$target"
check_sha "$target" "$expected"
complete=true
echo "ARM_SHIM1_$mode REBOOT_REQUIRED"
