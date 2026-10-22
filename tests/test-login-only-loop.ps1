param([string]$Adb='D:\LDPlayer\LDPlayer9\adb.exe', [string]$Serial='127.0.0.1:5555')
$ErrorActionPreference='Stop'
$app=Get-Content -LiteralPath (Join-Path $PSScriptRoot '../module-src/ldlogin/module/system/bin/app.sh') -Raw
$actions=$app.Substring($app.IndexOf('perform_login() {'))
$actions=$actions.Substring(0,$actions.IndexOf('# Thoi gian cho co dinh'))
$guards=$app.Substring($app.IndexOf('bot_may_act() {'))
$guards=$guards.Substring(0,$guards.IndexOf('# LDLogin''s native event frame'))
$main=$app.Substring($app.LastIndexOf("while true; do`n    # 1.", [StringComparison]::Ordinal))
if(!$main.StartsWith('while true; do')){throw 'Cannot locate production main loop'}
$main=$main.Replace('while true; do', 'while [ "$ITERATION" -lt 3 ]; do'+"`n"+'    ITERATION=$((ITERATION+1))')
$root='/data/local/tmp/ldlogin-loop-fixture-'+[guid]::NewGuid().ToString('N')
$setup=@'
ROOT=__ROOT__
case "$ROOT" in /data/local/tmp/ldlogin-loop-fixture-*) ;; *) exit 99 ;; esac
mkdir -m 700 "$ROOT" || exit 98
trap 'rm -f "$ROOT/finder" "$ROOT/ops" "$ROOT/mode" "$ROOT/alive"; rmdir "$ROOT"' EXIT
cat > "$ROOT/finder" <<'FINDER_EOF'
#!/system/bin/sh
printf 'FINDER %s\n' "$*" >> "$ROOT/ops"
case "$1" in
 --batch)
   if [ "$CASE" = off_during_scan ] && [ "$3" != --login-only ]; then
     echo MODE_OFF >> "$ROOT/ops"; echo 0 > "$ROOT/mode"; echo 'FOUND OK 480 400 1.00'; exit
   fi
   case "$CASE" in
     manual_login) echo 'FOUND LOGIN 480 190 1.00' ;;
     manual_ok) echo 'FOUND OK 480 400 1.00' ;;
     manual_menu) echo 'FOUND MENU 700 80 1.00' ;;
     manual_balo) echo 'FOUND BALO 910 310 1.00' ;;
     manual_confirm) echo 'FOUND CONFIRM 550 400 1.00' ;;
     *) echo NOT_FOUND ;;
   esac ;;
 --account) echo 'ACCOUNT|LD-Fixture|fixture_user|fixture_password' ;;
 --health)
   if [ "$CASE" = off_during_health ]; then echo MODE_OFF >> "$ROOT/ops"; echo 0 > "$ROOT/mode"; fi
   echo 'HEALTH 111 1 1.00' ;;
esac
FINDER_EOF
chmod 700 "$ROOT/finder"
export ROOT CASE
'@
$mocks=@'
log_msg() { :; }
reload_runtime_state() {
    local next
    next=$(cat "$ROOT/mode")
    if [ "$CASE" = manual_to_full ] && [ "$ITERATION" -ge 2 ]; then next=1; echo 1 > "$ROOT/mode"; fi
    if [ "$OPEN_BACKPACK" = 1 ] && [ "$next" = 0 ]; then GATE_BACKPACK_OFF_SEQUENCE=$((GATE_BACKPACK_OFF_SEQUENCE+1)); fi
    OPEN_BACKPACK="$next"
    if [ "$CASE" = master_off ]; then BOT_RUN_ALLOWED=0; BOT_ACTIVE=0; fi
    if [ "$CASE" = master_on_manual ]; then
        if [ "$ITERATION" -ge 2 ]; then BOT_RUN_ALLOWED=1; else BOT_RUN_ALLOWED=0; BOT_ACTIVE=0; fi
    fi
}
gate_clock() { GATE_NOW=$((GATE_NOW+101)); }
wait_bot_gate() {
    if [ "$CASE" = off_during_wait ] && [ "$scope" = automation ]; then
        echo MODE_OFF >> "$ROOT/ops"; echo 0 > "$ROOT/mode"; reload_runtime_state
    fi
}
sleep() { :; }
pidof() { echo PID_LOOKUP >> "$ROOT/ops"; [ "$(cat "$ROOT/alive")" != 1 ] || echo 999999; }
cmd() { echo COMMAND >> "$ROOT/ops"; echo 'test.fixture/.Main'; }
am() { echo "AM $*" >> "$ROOT/ops"; case "$1" in start) echo 1 > "$ROOT/alive" ;; esac; }
monkey() { echo MONKEY >> "$ROOT/ops"; echo 1 > "$ROOT/alive"; }
input() { echo "INPUT $*" >> "$ROOT/ops"; }
'@
$header=@'
FAILS=0
for CASE in manual_absent manual_login manual_ok manual_menu manual_balo manual_confirm master_off master_on_manual manual_to_full off_during_wait off_during_health off_during_scan; do
 : > "$ROOT/ops"
 OPEN_BACKPACK=0; BOT_RUN_ALLOWED=1; BOT_ACTIVE=0
 GATE_OFF_SEQUENCE=0; GATE_BACKPACK_OFF_SEQUENCE=0
 ITERATION=0; GATE_NOW=0; GATE_CHECK_SECONDS=5; GATE_IDLE_SECONDS=60
 CHECK_INT=5; GAME_LOAD_TIME=300; WAIT_BEFORE_MENU=0; DELAY_AFTER_BALO=2
 TARGET_PKG=test.fixture; FINDER_V2="$ROOT/finder"; IMAGES_DIR=images; ACCOUNT_DIR="$ROOT"
 CACHED_PID=''; LAST_BACKPACK_MODE=0; LAST_AUTOMATION_SEQUENCE=-1
 LAST_TIMER_CHECK=0; LAST_TIMER_PATTERN=''; TIMER_STUCK_COUNT=0; OK_STUCK_COUNT=0; LAST_OK_PRESENT=0
 echo 0 > "$ROOT/mode"; echo 0 > "$ROOT/alive"
 case "$CASE" in
  off_during_wait|off_during_health|off_during_scan)
   OPEN_BACKPACK=1; echo 1 > "$ROOT/mode"; echo 1 > "$ROOT/alive" ;;
 esac
 if [ "$CASE" = off_during_wait ]; then WAIT_BEFORE_MENU=30; fi
 if [ "$CASE" = off_during_health ]; then
   BOT_ACTIVE=1; LAST_BACKPACK_MODE=1; LAST_AUTOMATION_SEQUENCE=0
   LAST_TIMER_PATTERN=111; TIMER_STUCK_COUNT=2; LAST_OK_PRESENT=1; OK_STUCK_COUNT=2
 fi
'@
$checks=@'
 case "$CASE" in
  manual_*|master_off|master_on_manual)
   if [ "$CASE" != manual_to_full ] && grep -Eq 'PID_LOOKUP|AM |COMMAND|MONKEY|--health' "$ROOT/ops"; then echo "FAIL unexpected automation $CASE"; FAILS=$((FAILS+1)); fi ;;
 esac
 case "$CASE" in
  manual_absent)
   if [ "$(grep -c -- --login-only "$ROOT/ops")" = 3 ] && [ "$GATE_NOW" -gt 300 ]; then echo 'PASS manual mode continues scans beyond 300s with absent game'; else FAILS=$((FAILS+1)); fi ;;
  manual_login)
   if grep -q 'INPUT text fixture_user' "$ROOT/ops" && grep -q 'INPUT tap 480 316' "$ROOT/ops"; then echo 'PASS real account-entry flow works in manual mode'; else FAILS=$((FAILS+1)); fi ;;
  manual_ok|manual_menu|manual_balo|manual_confirm)
   if grep -q INPUT "$ROOT/ops"; then echo "FAIL non-login click $CASE"; FAILS=$((FAILS+1)); else echo "PASS no non-login click $CASE"; fi ;;
  master_off)
   if [ -s "$ROOT/ops" ]; then echo 'FAIL master OFF did work'; FAILS=$((FAILS+1)); else echo 'PASS master OFF does not scan or launch'; fi ;;
  master_on_manual)
   if [ "$(grep -c -- --login-only "$ROOT/ops")" = 2 ]; then echo 'PASS enabling LDLogin alone only scans login'; else echo 'FAIL enabling master did not resume login-only'; FAILS=$((FAILS+1)); fi ;;
  manual_to_full)
   if grep -q '^AM start' "$ROOT/ops"; then echo 'PASS enabling full mode can launch absent game'; else echo 'FAIL full mode did not resume'; FAILS=$((FAILS+1)); fi ;;
  off_during_*)
   if ! grep -q MODE_OFF "$ROOT/ops"; then echo "FAIL missing mode transition $CASE"; FAILS=$((FAILS+1)); fi
   if sed -n '/MODE_OFF/,$p' "$ROOT/ops" | grep -Eq 'PID_LOOKUP|AM |COMMAND|MONKEY|--health|INPUT'; then echo "FAIL automation after OFF $CASE"; FAILS=$((FAILS+1)); else echo "PASS automation stops $CASE"; fi ;;
 esac
done
echo "Failures: $FAILS"
exit "$FAILS"
'@
# All state and command replacements are confined to the generated scratch tree.
($setup.Replace('__ROOT__',$root)+"`n"+$actions+"`n"+$guards+"`n"+$mocks+"`n"+$header+"`n"+$main+"`n"+$checks).Replace("`r`n","`n") | & $Adb -s $Serial shell sh
if($LASTEXITCODE){throw "Login-only main loop fixture failed ($LASTEXITCODE)"}
