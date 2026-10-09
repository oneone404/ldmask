#!/system/bin/sh
set -eu
[ "$(id -u)" = 0 ]
source=/data/local/tmp
dest=/data/adb/.ldmask-tests-20261010
[ "$(readlink -f "$source")" = "$source" ]
[ ! -e "$dest" ] && [ ! -L "$dest" ]
names='audit-ldmenu-metadata.sh audit-ldmenu-sonames inspect-ldmenu-runtime.sh install-ld0-test3.sh ld0-test3-package ld0-test5-package ldmask-ld0-original-magisk32 ldmask-ld0-original-magisk64 ldmask-ld0-original-support.tar.gz ldmask-ld0-switch-test5-20261010 ldmask-ld0-test3-backup-20261010 ldmenu-arm-before-shim1.so ldmenu-arm-before-shim2.so ldmenu-arm-import-fixture ldmenu-arm-shim1.so ldmenu-arm-shim2-fixture ldmenu-arm-shim2.so ldmenu-original-arm64.so ldmenu-ram-audit-VocAnh ldmenu-ram-audit-v24oAU ldmenu-readonly-capture ldmenu-shim2-fd-fixture ldmenu-shim2-fixture-original.so ldmenu-shim2-fixture-payload.so ldmenu-tracer-ab.sh restore-ldmenu-cache switch-ldmenu-arm-shim1.sh switch-ldmenu-arm-shim2.sh verify-ld0-test3.sh'
# Validate every exact source before moving anything. No glob or recursive delete.
for name in $names; do
 [ -e "$source/$name" ] && [ ! -L "$source/$name" ]
 [ "$(readlink -f "$source/$name")" = "$source/$name" ]
done
mkdir -m 700 "$dest"
chown 0:0 "$dest"
[ "$(readlink -f "$dest")" = "$dest" ]
for name in $names; do
 [ ! -e "$dest/$name" ] && [ ! -L "$dest/$name" ]
 mv "$source/$name" "$dest/$name"
done
# Keep the parent root-only; nested backup attributes remain recoverable unchanged.
chmod 700 "$dest"
sync
echo TEST_ARTIFACTS_PRESERVED_ROOT_ONLY
