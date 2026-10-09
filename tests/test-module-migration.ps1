param([string]$Adb='D:\LDPlayer\LDPlayer9\adb.exe', [string]$Serial='127.0.0.1:5559')
$ErrorActionPreference='Stop'
# Non-root, unique sandbox. Never operates on real /data/adb or module settings.
$root='/data/local/tmp/ldmask-migration-fixture-'+[guid]::NewGuid().ToString('N')
$login=Get-Content -Raw (Join-Path $PSScriptRoot '../module-src/ldlogin/module/migrate.sh')
$menu=Get-Content -Raw (Join-Path $PSScriptRoot '../module-src/ldmenu/module/customize.sh')
$cleanup=Get-Content -Raw (Join-Path $PSScriptRoot '../app/src/main/res/raw/ldmask_cleanup_unlisted_modules.sh')
$login=$login.Replace('/data/adb', "$root/data/adb")
$menu=$menu.Replace('/data/adb', "$root/data/adb")
$cleanup=$cleanup.Replace('/data/adb', "$root/data/adb")
$header=@'
ROOT=__ROOT__
case "$ROOT" in /data/local/tmp/ldmask-migration-fixture-*) ;; *) exit 99 ;; esac
case "$ROOT" in *..*) exit 99 ;; esac
mkdir -p "$ROOT" || exit 99
cleanup_fixture() { [ ! -L "$ROOT" ] && rm -rf -- "$ROOT"; }
trap cleanup_fixture EXIT
FAILS=0
assert_case() {
    if [ "$2" = "$3" ]; then echo "PASS $1";
    else echo "FAIL $1 expected=$2 actual=$3"; FAILS=$((FAILS+1)); cat "$ROOT/output"; fi
}
reset_fixture() {
    [ ! -L "$ROOT" ] || exit 99
    rm -rf -- "$ROOT/data" "$ROOT/outside"
    mkdir -p "$ROOT/data/adb/modules" "$ROOT/data/adb/modules_update/ldlogin" "$ROOT/data/adb/modules_update/ldmenu/zygisk"
    touch "$ROOT/data/adb/modules_update/ldmenu/zygisk/x86_64.so" "$ROOT/data/adb/modules_update/ldmenu/zygisk/arm64-v8a.so"
}
make_legacy() {
    mkdir -p "$ROOT/data/adb/modules/$1" "$ROOT/data/adb/modules_update/$1"
    printf 'id=%s\n' "$1" > "$ROOT/data/adb/modules/$1/module.prop"
    printf 'id=%s\n' "$1" > "$ROOT/data/adb/modules_update/$1/module.prop"
}
'@
$mock=@'
id() { echo 0; }
abort() { echo "$*"; exit 91; }
ui_print() { :; }
set_perm_recursive() { :; }
'@
$header=$header.Replace('__ROOT__',$root)
$runLogin="(`n$mock`nMODPATH=`"`$ROOT/data/adb/modules_update/ldlogin`"`n$login`n) > `"`$ROOT/output`" 2>&1`nSTATUS=`$?`n"
$runMenu="(`n$mock`nMODPATH=`"`$ROOT/data/adb/modules_update/ldmenu`"`n$menu`n) > `"`$ROOT/output`" 2>&1`nSTATUS=`$?`n"
$runCleanup="(`n$mock`n$cleanup`n) > `"`$ROOT/output`" 2>&1`nSTATUS=`$?`n"
$program=$header+@'

reset_fixture
make_legacy oneone
mkdir -p "$ROOT/data/adb/oneone"
printf '{"enabled":true,"boot_wait_seconds":45,"logging":false}' > "$ROOT/data/adb/oneone/settings.json"
touch "$ROOT/data/adb/modules/oneone/disable"
'@+"`n$runLogin"+@'
assert_case migrate_login 0 "$STATUS"
[ ! -e "$ROOT/data/adb/oneone/settings.json" ] && grep -q '"boot_wait_seconds":45' "$ROOT/data/adb/ldlogin/settings.json"
assert_case settings_preserved 0 "$?"
[ -f "$ROOT/data/adb/modules/oneone/remove" ] && [ -f "$ROOT/data/adb/modules_update/oneone/remove" ] && [ -f "$ROOT/data/adb/modules_update/ldlogin/disable" ]
assert_case legacy_retired_disabled_inherited 0 "$?"
rm -f "$ROOT/data/adb/modules_update/ldlogin/disable"
'@+"`n$runLogin"+@'
assert_case repeated_install 0 "$STATUS"
[ ! -e "$ROOT/data/adb/modules_update/ldlogin/disable" ]
assert_case repeated_install_no_false_disable 0 "$?"
reset_fixture
mkdir -p "$ROOT/data/adb/ldlogin" "$ROOT/data/adb/oneone"
printf new > "$ROOT/data/adb/ldlogin/settings.json"
printf old > "$ROOT/data/adb/oneone/settings.json"
'@+"`n$runLogin"+@'
assert_case existing_settings_migrate 0 "$STATUS"
[ "$(cat "$ROOT/data/adb/ldlogin/settings.json")" = new ] && [ "$(cat "$ROOT/data/adb/oneone/settings.json")" = old ]
assert_case never_overwrite_existing 0 "$?"
reset_fixture
mkdir -p "$ROOT/outside"
ln -s "$ROOT/outside" "$ROOT/data/adb/oneone"
'@+"`n$runLogin"+@'
assert_case login_refuse_symlink 91 "$STATUS"
[ ! -e "$ROOT/outside/settings.json" ] && [ ! -e "$ROOT/data/adb/ldlogin" ]
assert_case rejected_migration_untouched 0 "$?"
reset_fixture
make_legacy ktools_zygisk
touch "$ROOT/data/adb/modules_update/ktools_zygisk/disable"
'@+"`n$runMenu"+@'
assert_case migrate_menu 0 "$STATUS"
[ -f "$ROOT/data/adb/modules/ktools_zygisk/remove" ] && [ -f "$ROOT/data/adb/modules_update/ktools_zygisk/remove" ] && [ -f "$ROOT/data/adb/modules_update/ldmenu/disable" ]
assert_case menu_retired_disabled_inherited 0 "$?"
rm -f "$ROOT/data/adb/modules_update/ldmenu/disable"
'@+"`n$runMenu"+@'
assert_case repeated_menu_install 0 "$STATUS"
[ ! -e "$ROOT/data/adb/modules_update/ldmenu/disable" ]
assert_case repeated_menu_no_false_disable 0 "$?"
reset_fixture
mkdir -p "$ROOT/data/adb/modules/ldlogin" "$ROOT/data/adb/modules/ldmenu" "$ROOT/data/adb/modules/extra" "$ROOT/data/adb/modules_update/extra"
KEEP_LDLOGIN=1; KEEP_LDMENU=1
'@+"`n$runCleanup"+@'
assert_case cleanup_server_list 0 "$STATUS"
[ ! -e "$ROOT/data/adb/modules/ldlogin/remove" ] && [ ! -e "$ROOT/data/adb/modules/ldmenu/remove" ] && [ -f "$ROOT/data/adb/modules/extra/remove" ] && [ -f "$ROOT/data/adb/modules_update/extra/remove" ]
assert_case preserve_allowed_mark_unknown_active_staged 0 "$?"
KEEP_LDMENU=0
'@+"`n$runCleanup"+@'
assert_case cleanup_unpublished_menu 0 "$STATUS"
[ -f "$ROOT/data/adb/modules/ldmenu/remove" ] && [ -f "$ROOT/data/adb/modules_update/ldmenu/remove" ] && [ ! -e "$ROOT/data/adb/modules/ldlogin/remove" ]
assert_case unpublished_retired 0 "$?"
reset_fixture
mkdir -p "$ROOT/data/adb/modules/aaa" "$ROOT/outside"
ln -s "$ROOT/outside" "$ROOT/data/adb/modules/zzz"
KEEP_LDLOGIN=1; KEEP_LDMENU=1
'@+"`n$runCleanup"+@'
assert_case cleanup_symlink_refused 13 "$STATUS"
[ ! -e "$ROOT/data/adb/modules/aaa/remove" ] && [ ! -e "$ROOT/outside/remove" ]
assert_case preflight_no_partial_mark 0 "$?"
reset_fixture
mkdir -p "$ROOT/data/adb/modules/extra"
touch "$ROOT/outside"
ln -s "$ROOT/outside" "$ROOT/data/adb/modules/extra/remove"
'@+"`n$runCleanup"+@'
assert_case cleanup_symlink_flag_refused 15 "$STATUS"
[ ! -e "$ROOT/data/adb/modules/extra/disable" ]
assert_case invalid_flag_no_write 0 "$?"
reset_fixture
KEEP_LDLOGIN=0; KEEP_LDMENU=0
'@+"`n$runCleanup"+@'
assert_case cleanup_empty_allowlist_refused 11 "$STATUS"
echo "Failures: $FAILS"
exit "$FAILS"
'@
$program.Replace("`r`n","`n") | & $Adb -s $Serial shell sh
if ($LASTEXITCODE -ne 0) { throw "Migration fixture failed (exit $LASTEXITCODE)" }
