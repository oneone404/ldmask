#!/system/bin/sh
set -eu
[ "$(id -u)" = 0 ]
dir=/data/adb/modules/ldmenu
flag=$dir/disable
tag=ldmask-ab-tracer-20261010
[ "$(readlink -f "$dir")" = "$dir" ] && [ -d "$dir" ]
[ ! -e "$dir/remove" ]
value=$(sha256sum "$dir/zygisk/arm64-v8a.so")
[ "${value%% *}" = 4cf0e7cad0cc89848a6aa5bb5d24486a45931c20b7df9fe7aed71798b43a5069 ]
case "${1:?off or on}" in
 off)
  [ ! -e "$flag" ] && [ ! -L "$flag" ]
  (umask 077; set -C; printf '%s\n' "$tag" > "$flag")
  echo LDMENU_AB_DISABLED_REBOOT_REQUIRED ;;
 on)
  [ -f "$flag" ] && [ ! -L "$flag" ]
  [ "$(cat "$flag")" = "$tag" ]
  rm "$flag"
  echo LDMENU_AB_RESTORED_REBOOT_REQUIRED ;;
 *) exit 2 ;;
esac
sync
