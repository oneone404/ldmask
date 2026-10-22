param([string]$Adb='D:\LDPlayer\LDPlayer9\adb.exe', [string]$Serial='emulator-5554')
$ErrorActionPreference='Stop'
# Source the real action functions, but replace all screenshot, input, launch,
# clock and settings IO with deterministic mocks. No real game/root operation.
$app=Get-Content -LiteralPath (Join-Path $PSScriptRoot '../module-src/ldlogin/module/system/bin/app.sh') -Raw
$functions=$app.Substring($app.IndexOf('perform_login() {'))
$functions=$functions.Substring(0,$functions.IndexOf('# Thoi gian cho co dinh'))
$guard=$app.Substring($app.IndexOf('bot_may_act() {'))
$guard=$guard.Substring(0,$guard.IndexOf('# LDLogin''s native event frame'))
$realSleep=$guard.Substring($guard.IndexOf('sleep_with_gate() {')).Replace('sleep_with_gate() {','real_sleep_with_gate() {')
$program=$functions+"`n"+$guard+"`n"+$realSleep+"`n"+@'
BOT_RUN_ALLOWED=1; BOT_ACTIVE=1
OPEN_BACKPACK=1; GATE_OFF_SEQUENCE=0; GATE_BACKPACK_OFF_SEQUENCE=0
WAIT_BEFORE_MENU=0; CHECK_INT=1; GAME_LOAD_TIME=15; DELAY_AFTER_BALO=2
IMG_BALO=backpack; IMG_VOT=racket; IMAGES_DIR=images; TARGET_PKG=test.fixture
FAILS=0
log_msg() {
    case "$CASE:$1" in off_in_retry:*'Chua tim thay vot'*) OPEN_BACKPACK=0 ;; esac
}
reload_runtime_state() { :; }
pidof() { echo 123; }
am() { FAILS=$((FAILS+1)); echo 'FAIL unexpected real-launch path'; }
monkey() { FAILS=$((FAILS+1)); }
input() { INPUTS="$INPUTS|$*"; }
perform_login() { LOGINS=$((LOGINS+1)); }
gate_clock() { GATE_NOW=$((GATE_NOW+1)); }
wait_bot_gate() { [ "$CASE" != rapid_toggle ] || GATE_BACKPACK_OFF_SEQUENCE=$((GATE_BACKPACK_OFF_SEQUENCE+1)); }
sleep_with_gate() {
    if [ "$CASE" = off_in_delay ] && [ "$1" = 2 ] && [ "$2" = backpack ]; then OPEN_BACKPACK=0; return 1; fi
    if [ "$CASE" = off_in_wait ] && [ "$2" = backpack ]; then OPEN_BACKPACK=0; return 1; fi
    bot_may_act || return 1
    [ "$2" != backpack ] || [ "$OPEN_BACKPACK" = 1 ]
}
FINDER_V2=__FINDER__
assert_contains() {
    case "$INPUTS" in *"$2"*) echo "PASS $1" ;; *) echo "FAIL $1 inputs=$INPUTS"; FAILS=$((FAILS+1)) ;; esac
}
assert_empty() {
    if [ -z "$INPUTS" ]; then echo "PASS $1"; else echo "FAIL $1 inputs=$INPUTS"; FAILS=$((FAILS+1)); fi
}
for CASE in stale_balo menu login confirm ok; do
    OPEN_BACKPACK=0; INPUTS=''; LOGINS=0; GATE_NOW=0; GAME_LOAD_TIME=15
    scan_login_only
    case "$CASE" in
        stale_balo|menu|confirm|ok) assert_empty "login-only rejects $CASE even if finder returns stale result" ;;
        login) assert_contains 'login-only taps LOGIN' 'tap 480 190'; [ "$LOGINS" -gt 0 ] || FAILS=$((FAILS+1)) ;;
    esac
done
for CASE in found_racket fallback off_in_delay off_in_retry off_in_wait; do
    OPEN_BACKPACK=1; INPUTS=''; LOGINS=0; GATE_NOW=0; GAME_LOAD_TIME=100
    handle_post_restart
    if [ "$CASE" = off_in_wait ]; then assert_empty 'disable during pre-backpack wait prevents opening'; continue; fi
    assert_contains "$CASE opens fresh-checked backpack" 'tap 910 310'
    case "$CASE" in
        off_in_delay|off_in_retry)
            case "$INPUTS" in *'tap 130 200'*) echo 'FAIL disabled backpack reached racket'; FAILS=$((FAILS+1)) ;; *) echo 'PASS disable during panel delay prevents racket/fallback' ;; esac ;;
        *) assert_contains "$CASE taps racket once" 'tap 130 200' ;;
    esac
done
CASE=rapid_toggle; OPEN_BACKPACK=1; GATE_NOW=0
if real_sleep_with_gate 5 backpack; then echo 'FAIL rapid toggle did not cancel pending backpack wait'; FAILS=$((FAILS+1)); else echo 'PASS rapid OFF/ON invalidates pending backpack wait'; fi
echo "Failures: $FAILS"
exit "$FAILS"
'@
# The real function checks -x before calling the finder. A unique temporary
# executable is necessary; it only prints canned fixture results.
$root='/data/local/tmp/ldlogin-backpack-fixture-'+[guid]::NewGuid().ToString('N')
$setup=@'
ROOT=__ROOT__
case "$ROOT" in /data/local/tmp/ldlogin-backpack-fixture-*) ;; *) exit 99 ;; esac
mkdir -m 700 "$ROOT" || exit 98
trap 'rm -f "$ROOT/finder"; rmdir "$ROOT"' EXIT
cat > "$ROOT/finder" <<'FINDER_EOF'
#!/system/bin/sh
case "$1" in
 --batch) case "$CASE" in
 login) echo 'FOUND LOGIN 480 190 1.00' ;; menu) echo 'FOUND MENU 700 80 1.00' ;;
 confirm) echo 'FOUND CONFIRM 550 400 1.00' ;; ok) echo 'FOUND OK 480 400 1.00' ;;
 *) echo 'FOUND BALO 910 310 1.00' ;; esac ;;
 backpack) echo 'FOUND 910 310 1.00' ;;
 racket) if [ "$CASE" = found_racket ]; then echo 'FOUND 130 200 1.00'; else echo NOT_FOUND; fi ;;
esac
FINDER_EOF
chmod 700 "$ROOT/finder"
export CASE
'@
# Fixture script creation happens only in the generated Android scratch tree.
($setup.Replace('__ROOT__',$root)+"`n"+$program.Replace('__FINDER__',"$root/finder")).Replace("`r`n","`n") | & $Adb -s $Serial shell sh
if($LASTEXITCODE -ne 0){throw "Backpack action fixture failed ($LASTEXITCODE)"}
