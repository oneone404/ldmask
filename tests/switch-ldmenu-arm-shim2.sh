#!/system/bin/sh
set -eu
[ "$(id -u)" = 0 ]
target=/data/adb/modules/ldmenu/zygisk/arm64-v8a.so
temp=/data/adb/modules/ldmenu/zygisk/.arm64-v8a.shim2
recovery=/data/adb/.ldmask-tests-20261010
original=$recovery/ldmenu-arm-before-shim2.so
trial=$recovery/ldmenu-arm-shim2.so
old=4cf0e7cad0cc89848a6aa5bb5d24486a45931c20b7df9fe7aed71798b43a5069
new=5916e728bbc8f71d411d88cd8841f28d19155fd8da475e6a316fde9781de11f0
check_sha() { value=$(sha256sum "$1") || exit 21; [ "${value%% *}" = "$2" ] || exit 22; }
[ -f "$target" ] && [ ! -L "$target" ] && [ "$(readlink -f "$target")" = "$target" ] || exit 23
[ ! -e "$temp" ] && [ ! -L "$temp" ] || exit 24
[ ! -e /data/adb/modules/ldmenu/disable ] && [ ! -e /data/adb/modules/ldmenu/remove ] || exit 25
case "${1:?install or rollback}" in
 install)
  check_sha "$target" "$old"; check_sha "$trial" "$new"
  [ ! -e "$original" ] && [ ! -L "$original" ] || exit 26
  cp -p "$target" "$original"; check_sha "$original" "$old"
  source=$trial; expected=$new ;;
 refresh)
  check_sha "$target" 860462df64d22af79d8c1bf0e26abc6744889a6394a1805da0c51073afe60e72
  check_sha "$original" "$old"; check_sha "$trial" "$new"
  source=$trial; expected=$new ;;
 rollback)
  check_sha "$target" "$new"; check_sha "$original" "$old"
  [ -f "$recovery/restore-ldmenu-cache" ] && [ ! -L "$recovery/restore-ldmenu-cache" ]
  check_sha "$recovery/restore-ldmenu-cache" 4910f14326d68c5f24ce3e372200bd3b623c953b7149fd167280f335f1ecb261
  am force-stop com.vng.playtogether
  "$recovery/restore-ldmenu-cache"
  source=$original; expected=$old ;;
 *) exit 20 ;;
esac
complete=false
cleanup() {
 if [ "$complete" != true ]; then
  cp -p "$original" "$target"
  chmod 644 "$target"; chown 0:0 "$target"; chcon u:object_r:system_file:s0 "$target"
 fi
 rm -f "$temp"
 sync
}
trap cleanup EXIT
cp "$source" "$temp"
chmod 644 "$temp"; chown 0:0 "$temp"; chcon u:object_r:system_file:s0 "$temp"
check_sha "$temp" "$expected"
mv "$temp" "$target"
check_sha "$target" "$expected"
complete=true
echo "ARM_SHIM2_${1}_REBOOT_REQUIRED"
