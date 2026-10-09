param([string]$Adb='D:\LDPlayer\LDPlayer9\adb.exe', [string]$Serial='127.0.0.1:5559')
$ErrorActionPreference='Stop'
# Runtime fixture files only: no root, real remount, su, module, or APK action.
$root='/data/local/tmp/ldmask-fixture-' + [guid]::NewGuid().ToString('N')
$su=Get-Content -Raw (Join-Path $PSScriptRoot '../app/src/main/res/raw/ldmask_remove_system_su.sh')
$verify=Get-Content -Raw (Join-Path $PSScriptRoot '../app/src/main/res/raw/ldmask_verify_system_su.sh')
$all=Get-Content -Raw (Join-Path $PSScriptRoot '../app/src/main/res/raw/ldmask_remove_all_modules.sh')
$su=$su.Replace('/system/', "$root/system/").Replace('/data/adb', "$root/data/adb").Replace('/sbin', "$root/sbin").Replace('/proc/mounts', "$root/mounts")
$verify=$verify.Replace('/system/', "$root/system/").Replace('/sbin', "$root/sbin")
$all=$all.Replace('/data/adb', "$root/data/adb")
function Quote-TestShell([string]$value) { "'" + $value.Replace("'", "'\''") + "'" }
$header=@'
set -u
ROOT=__ROOT__
mkdir -p "$ROOT"
cleanup() {
    case "$ROOT" in /data/local/tmp/ldmask-fixture-*) ;; *) exit 9 ;; esac
    [ -d "$ROOT" ] && [ ! -L "$ROOT" ] && rm -rf -- "$ROOT"
}
trap cleanup EXIT
reset() {
    case "$ROOT" in /data/local/tmp/ldmask-fixture-*) ;; *) exit 9 ;; esac
    rm -rf -- "$ROOT/system" "$ROOT/data" "$ROOT/sbin" "$ROOT/deny-ro"
    mkdir -p "$ROOT/system/bin" "$ROOT/system/xbin" "$ROOT/sbin" "$ROOT/data/adb"
    printf '#!/system/bin/sh\nexit 0\n' > "$ROOT/sbin/magisk"
    ln -s ./magisk "$ROOT/sbin/su"
    chmod 700 "$ROOT/sbin/magisk"
    printf 'mock / ext4 ro,relatime 0 0\n' > "$ROOT/mounts"
}
FAILS=0
assert_case() {
    NAME=$1; EXPECTED=$2; ACTUAL=$3
    if [ "$EXPECTED" != "$ACTUAL" ]; then
        echo "FAIL $NAME expected=$EXPECTED actual=$ACTUAL"; FAILS=$((FAILS+1))
        cat "$ROOT/output"
    else echo "PASS $NAME"; fi
}
'@
$mock=@'
ROOT=__ROOT__
ORIGINAL_APP_PATH=$ROOT/sbin
id() { echo 0; }
magisk() { echo "$ROOT/sbin"; }
# Root discovery is mocked; the suite exercises cleanup after the root guard.
readlink() { echo "$ROOT/sbin/magisk"; }
rm() {
    case "$*" in
        *"$ROOT/system/"*)
            if grep -q ' ro,' "$ROOT/mounts"; then return 1; fi ;;
    esac
    command rm "$@"
}
mount() {
    # This function NEVER calls the real mount command.
    case "$*" in
        *ro,remount*)
            if [ -f "$ROOT/deny-ro" ]; then echo 'mock: Device or resource busy' >&2; return 1; fi
            printf 'mock / ext4 ro,relatime 0 0\n' > "$ROOT/mounts" ;;
        *rw,remount*) printf 'mock / ext4 rw,relatime 0 0\n' > "$ROOT/mounts" ;;
        *) return 1 ;;
    esac
}
'@
$header=$header.Replace('__ROOT__', (Quote-TestShell $root))
$mock=$mock.Replace('__ROOT__', (Quote-TestShell $root))
$runSu="(`n$mock`n$su`n) > `"`$ROOT/output`" 2>&1`nSTATUS=`$?`n"
$runVerify="(`n$mock`n$verify`n) > `"`$ROOT/output`" 2>&1`nSTATUS=`$?`n"
$runAll="(`n$mock`n$all`n) > `"`$ROOT/output`" 2>&1`nSTATUS=`$?`n"
$program=$header + "`nreset`n" + $runSu + @'
assert_case absent_ro 0 "$STATUS"
reset
touch "$ROOT/system/bin/su" "$ROOT/system/xbin/su"
'@ + "`n$runSu" + @'
assert_case delete_and_restore 0 "$STATUS"
[ ! -e "$ROOT/system/bin/su" ] && [ ! -e "$ROOT/system/xbin/su" ] && grep -q ' ro,' "$ROOT/mounts"
assert_case targets_gone_mount_ro 0 "$?"
reset
touch "$ROOT/system/xbin/su" "$ROOT/deny-ro"
'@ + "`n$runSu" + @'
assert_case restore_refused 1 "$STATUS"
[ ! -e "$ROOT/system/xbin/su" ] && [ -f "$ROOT/data/adb/ldmask/system-su-ro-pending" ] && grep -q ' rw,' "$ROOT/mounts"
assert_case partial_result_persisted 0 "$?"
'@ + "`n$runVerify" + @'
assert_case verification_succeeds_after_failed_remount 0 "$STATUS"
'@ + "`n$runSu" + @'
assert_case second_click_still_fails 1 "$STATUS"
rm -f "$ROOT/deny-ro"
'@ + "`n$runSu" + @'
assert_case pending_mount_recovered 0 "$STATUS"
[ ! -e "$ROOT/data/adb/ldmask/system-su-ro-pending" ] && grep -q ' ro,' "$ROOT/mounts"
assert_case recovery_state_cleared 0 "$?"
reset
printf 'mock / ext4 rw,relatime 0 0\n' > "$ROOT/mounts"
'@ + "`n$runSu" + @'
assert_case old_version_rw_not_success 1 "$STATUS"
'@ + "`n$runVerify" + @'
assert_case verified_absence_despite_rw 0 "$STATUS"
grep -qx LDMASK_SYSTEM_SU_REMOVED "$ROOT/output"
assert_case verified_success_marker 0 "$?"
touch "$ROOT/system/bin/su"
'@ + "`n$runVerify" + @'
assert_case remaining_su_not_success 1 "$STATUS"
rm -f "$ROOT/system/bin/su"
ln -s /nonexistent-fixture-target "$ROOT/system/xbin/su"
'@ + "`n$runVerify" + @'
assert_case dangling_su_not_success 1 "$STATUS"
reset
rm -f "$ROOT/sbin/su"
'@ + "`n$runVerify" + @'
assert_case lost_independent_root_not_success 1 "$STATUS"
reset
mkdir -p "$ROOT/data/adb/modules/oneone" "$ROOT/data/adb/modules_update/oneone" "$ROOT/data/adb/modules_update/ktools_zygisk"
'@ + "`n$runAll" + @'
assert_case mark_active_and_staged 0 "$STATUS"
[ -f "$ROOT/data/adb/modules/oneone/remove" ] && [ -f "$ROOT/data/adb/modules_update/oneone/remove" ] && [ -f "$ROOT/data/adb/modules_update/ktools_zygisk/remove" ]
assert_case all_markers_present 0 "$?"
reset
mkdir -p "$ROOT/data/adb/modules" "$ROOT/external"
ln -s "$ROOT/external" "$ROOT/data/adb/modules/unsafe"
'@ + "`n$runAll" + @'
assert_case refuse_symlink_folder 1 "$STATUS"
[ ! -e "$ROOT/external/remove" ]
assert_case symlink_destination_untouched 0 "$?"
echo "Failures: $FAILS"
exit "$FAILS"
'@
# Stream test code to Android sh; only the fixed, unique fixture tree is touched.
$program.Replace("`r`n","`n") | & $Adb -s $Serial shell sh
if ($LASTEXITCODE -ne 0) { throw "Android fixture tests failed (exit $LASTEXITCODE)" }
