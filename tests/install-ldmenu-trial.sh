#!/system/bin/sh
set -eu
# Only LD1 is selected by the host runner. Update precisely two persistent
# executables, never the active /sbin executable or any module/game data.
[ "$(id -u)" = 0 ]
[ "$(magisk --path)" = /sbin ]
base=/system/etc/init/magisk
[ "$(readlink -f "$base")" = "$base" ] && [ ! -L "$base" ]
old32=18c301ee43636a345bd671befb3c3824f7e11e6079c6c1343f0b6d30fcf77c14
old64=b7bce3e50633cef317a4827e0bf52547872e4bf1a234b6e44375dd0b31638325
prior32=08a67e7825ca29e28c24236a5204ff03901f4d9fefc9f7fa75313ae16c0f0ed7
prior64=48db38f838756cabfb1f6b6b7b8fff0ba994996062c540f388321bc013becc06
new32=e0aba007d4b92eb4bc978613a590a9c80c58223213458a693f1e32610402867d
new64=707eacefc41c82f12100be0a1be517ebeb95982beca3e9a49465fa5d763ed3e3
tested32=fea3ef011190653a8a3f9a1c913ca7876a5894d35a241ff770370371987ccb5a
tested64=37577e0f62eda5f603ed602cb33c009ce68fcd1846e5f0bdd2294324aac6c9d1
mode=${1:-install}
hash() { actual=$(sha256sum "$1"); actual=${actual%% *}; [ "$actual" = "$2" ]; }
for b in magisk32 magisk64; do
    [ -f "$base/$b" ] && [ ! -L "$base/$b" ]
    [ ! -e "$base/.$b.ldmenu-trial1" ] && [ ! -L "$base/.$b.ldmenu-trial1" ]
done
hash /data/local/tmp/ldmenu-stable-magisk32 "$old32"
hash /data/local/tmp/ldmenu-stable-magisk64 "$old64"
hash /data/local/tmp/ldmenu-test1-magisk32 "$new32"
hash /data/local/tmp/ldmenu-test1-magisk64 "$new64"
case "$mode" in
 install)
  if hash "$base/magisk32" "$prior32"; then
   hash "$base/magisk64" "$prior64"
  else
   hash "$base/magisk32" "$old32"; hash "$base/magisk64" "$old64"
  fi
  source=ldmenu-test1; dest32=$new32; dest64=$new64 ;;
 rollback)
  hash "$base/magisk32" "$new32"; hash "$base/magisk64" "$new64"
  source=ldmenu-stable; dest32=$old32; dest64=$old64 ;;
 restore-tested)
  hash "$base/magisk32" "$new32"; hash "$base/magisk64" "$new64"
  hash /data/local/tmp/ldmenu-tested-magisk32 "$tested32"
  hash /data/local/tmp/ldmenu-tested-magisk64 "$tested64"
  source=ldmenu-tested; dest32=$tested32; dest64=$tested64 ;;
 *) exit 20 ;;
esac
mount -o remount,rw /
installed=false
cleanup() {
 if [ "$installed" != true ]; then
  cp /data/local/tmp/ldmenu-stable-magisk32 "$base/magisk32"
  cp /data/local/tmp/ldmenu-stable-magisk64 "$base/magisk64"
  chmod 700 "$base/magisk32" "$base/magisk64"
  chcon u:object_r:system_file:s0 "$base/magisk32" "$base/magisk64"
 fi
 rm -f "$base/.magisk32.ldmenu-trial1" "$base/.magisk64.ldmenu-trial1"
 sync
 mount -o remount,ro / || echo ROOT_REMOUNT_RO_FAILED_REBOOT_REQUIRED
}
trap cleanup EXIT
for b in magisk32 magisk64; do
 cp /data/local/tmp/$source-$b "$base/.$b.ldmenu-trial1"
 chmod 700 "$base/.$b.ldmenu-trial1"
 chcon u:object_r:system_file:s0 "$base/.$b.ldmenu-trial1"
done
mv "$base/.magisk32.ldmenu-trial1" "$base/magisk32"
mv "$base/.magisk64.ldmenu-trial1" "$base/magisk64"
hash "$base/magisk32" "$dest32"; hash "$base/magisk64" "$dest64"
installed=true
echo "$mode STAGED_REBOOT_REQUIRED"
