#!/system/bin/sh
set -eu
# Bounded existing-root trial switch for LD index 0. No module/game mutations.
mode=${1:-test3}
case "$mode" in
 test3)
  stage=/data/local/tmp/ld0-test3-package
  backup=/data/local/tmp/ldmask-ld0-test3-backup-20261010
  before32=2f7fb2a84b36aa4a5eeb169852ab0de3c847440631c6364da3393ef01ca5fb06
  before64=2798f834651ebab3046be0ed9ad626dd6068e23410372bcd1fcc6e781ebd1209
  after32=fea3ef011190653a8a3f9a1c913ca7876a5894d35a241ff770370371987ccb5a
  after64=37577e0f62eda5f603ed602cb33c009ce68fcd1846e5f0bdd2294324aac6c9d1
  version=LDMask-1.0.13-ldmenu-test3 ;;
 test5)
  stage=/data/local/tmp/ld0-test5-package
  backup=/data/local/tmp/ldmask-ld0-switch-test5-20261010
  before32=fea3ef011190653a8a3f9a1c913ca7876a5894d35a241ff770370371987ccb5a
  before64=37577e0f62eda5f603ed602cb33c009ce68fcd1846e5f0bdd2294324aac6c9d1
  after32=e0aba007d4b92eb4bc978613a590a9c80c58223213458a693f1e32610402867d
  after64=707eacefc41c82f12100be0a1be517ebeb95982beca3e9a49465fa5d763ed3e3
  version=LDMask-1.0.13-ldmenu-test5 ;;
 restore-test3)
  stage=/data/local/tmp/ld0-test3-package
  backup=/data/local/tmp/ldmask-ld0-restore-test3-20261010
  before32=e0aba007d4b92eb4bc978613a590a9c80c58223213458a693f1e32610402867d
  before64=707eacefc41c82f12100be0a1be517ebeb95982beca3e9a49465fa5d763ed3e3
  after32=fea3ef011190653a8a3f9a1c913ca7876a5894d35a241ff770370371987ccb5a
  after64=37577e0f62eda5f603ed602cb33c009ce68fcd1846e5f0bdd2294324aac6c9d1
  version=LDMask-1.0.13-ldmenu-test3 ;;
 *) exit 20 ;;
esac
system=/system/etc/init/magisk
data=/data/adb/magisk
files='magisk32 magisk64 magiskinit magiskpolicy stub.apk'
datafiles='magisk32 magisk64 magiskinit magiskpolicy stub.apk magiskboot busybox util_functions.sh boot_patch.sh addon.d.sh'
check_sha() { result=$(sha256sum "$1") || exit 21; [ "${result%% *}" = "$2" ] || exit 22; }
[ "$(id -u)" = 0 ]
[ "$(magisk --path)" = /sbin ]
for dir in "$system" "$data" "$stage"; do
    [ -d "$dir" ] && [ ! -L "$dir" ] && [ "$(readlink -f "$dir")" = "$dir" ] || exit 23
done
[ ! -e "$backup" ] && [ ! -L "$backup" ]
check_sha "$system/magisk32" "$before32"
check_sha "$system/magisk64" "$before64"
check_sha "$stage/magisk32" "$after32"
check_sha "$stage/magisk64" "$after64"
grep -qx "MAGISK_VER='$version'" "$stage/util_functions.sh"
grep -qx 'MAGISK_VER_CODE=27015' "$stage/util_functions.sh"
for file in $datafiles; do
    [ -f "$stage/$file" ] && [ ! -L "$stage/$file" ]
    [ -f "$data/$file" ] && [ ! -L "$data/$file" ]
    [ ! -e "$data/.$file.ld0-test3" ] && [ ! -L "$data/.$file.ld0-test3" ]
done
for file in $files; do
    [ -f "$system/$file" ] && [ ! -L "$system/$file" ]
    [ ! -e "$system/.$file.ld0-test3" ] && [ ! -L "$system/.$file.ld0-test3" ]
done
mkdir -m 700 "$backup"
mkdir -m 700 "$backup/system" "$backup/data"
for file in $files; do cp -p "$system/$file" "$backup/system/$file"; done
for file in $datafiles; do cp -p "$data/$file" "$backup/data/$file"; done
cp -p "$system/config" "$backup/system/config"
committed=false
cleanup() {
    if [ "$committed" != true ]; then
        echo UPDATE_FAILED_RESTORING_ORIGINAL
        for file in $files; do
            cp -p "$backup/system/$file" "$system/$file" || echo RESTORE_FAILED_SYSTEM_$file
            chcon u:object_r:system_file:s0 "$system/$file" || true
        done
        for file in $datafiles; do
            cp -p "$backup/data/$file" "$data/$file" || echo RESTORE_FAILED_DATA_$file
            chcon u:object_r:system_file:s0 "$data/$file" || true
        done
    fi
    for file in $files; do rm -f "$system/.$file.ld0-test3"; done
    for file in $datafiles; do rm -f "$data/.$file.ld0-test3"; done
    sync
    mount -o remount,ro / || echo ROOT_REMOUNT_RO_FAILED_REBOOT_REQUIRED
}
mount -o remount,rw /
trap cleanup EXIT
for file in $files; do
    cp "$stage/$file" "$system/.$file.ld0-test3"
    chmod 700 "$system/.$file.ld0-test3"
    chown 0:0 "$system/.$file.ld0-test3"
    chcon u:object_r:system_file:s0 "$system/.$file.ld0-test3"
done
for file in $datafiles; do
    cp "$stage/$file" "$data/.$file.ld0-test3"
    chmod 755 "$data/.$file.ld0-test3"
    chown 0:0 "$data/.$file.ld0-test3"
    chcon u:object_r:system_file:s0 "$data/.$file.ld0-test3"
done
for file in $files; do mv "$system/.$file.ld0-test3" "$system/$file"; done
for file in $datafiles; do mv "$data/.$file.ld0-test3" "$data/$file"; done
for file in $files; do cmp -s "$stage/$file" "$system/$file"; done
for file in $datafiles; do cmp -s "$stage/$file" "$data/$file"; done
cmp -s "$system/config" "$backup/system/config"
committed=true
echo "LD0_${mode}_STAGED_REBOOT_REQUIRED"
