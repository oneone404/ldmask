param([string]$Adb='D:\LDPlayer\LDPlayer9\adb.exe', [string]$Serial='127.0.0.1:5559')
$ErrorActionPreference='Stop'
# Mock ALL root/package/activity commands; never open or stop the real game.
$root='/data/local/tmp/ldmask-launch-fixture-'+[guid]::NewGuid().ToString('N')
$script=Get-Content -Raw (Join-Path $PSScriptRoot '../app/src/main/res/raw/ldmask_open_game.sh')
$header=@'
ROOT=__ROOT__
case "$ROOT" in /data/local/tmp/ldmask-launch-fixture-*) ;; *) exit 99 ;; esac
case "$ROOT" in *..*) exit 99 ;; esac
mkdir -p "$ROOT" || exit 99
cleanup_fixture() { [ ! -L "$ROOT" ] && rm -rf -- "$ROOT"; }
trap cleanup_fixture EXIT
FAILS=0
run_case() {
    MODE=$1; EXPECTED=$2
    : > "$ROOT/trace"
    OUTPUT=$(
        id() { if [ "$MODE" = noroot ]; then echo 2000; else echo 0; fi; }
        cmd() {
            echo resolve >> "$ROOT/trace"
            case "$MODE" in
                missing) echo 'No activity found' ;;
                foreign) echo 'com.other.game/.Main' ;;
                malformed) echo 'com.vng.playtogether/.Main with space' ;;
                *) echo 'com.vng.playtogether/com.google.firebase.MessagingUnityPlayerActivity' ;;
            esac
        }
        am() {
            printf '%s\n' "am $*" >> "$ROOT/trace"
            case "$MODE" in
                startfail) echo 'Error: Activity not started'; return 1 ;;
                errorzero) echo 'Error: Permission denied'; return 0 ;;
                exception) echo 'java.lang.SecurityException'; return 0 ;;
                alreadyrunning) echo 'Warning: Activity not started, current task brought to the front'; return 0 ;;
                *) echo 'Starting: Intent { mock }'; return 0 ;;
            esac
        }
        __SCRIPT__
    )
    STATUS=$?
    if [ "$STATUS" != "$EXPECTED" ]; then echo "FAIL $MODE status=$STATUS"; FAILS=$((FAILS+1)); return; fi
    case "$MODE" in
        noroot|missing|foreign|malformed)
            if grep -q '^am ' "$ROOT/trace"; then echo "FAIL $MODE launched"; FAILS=$((FAILS+1)); return; fi ;;
        *)
            EXPECT_TRACE='resolve
am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n com.vng.playtogether/com.google.firebase.MessagingUnityPlayerActivity'
            if [ "$(cat "$ROOT/trace")" != "$EXPECT_TRACE" ]; then echo "FAIL $MODE command sequence"; FAILS=$((FAILS+1)); return; fi ;;
    esac
    if [ "$EXPECTED" = 0 ]; then
        if [ "$OUTPUT" != LDLOGIN_LAUNCH_SENT ]; then echo "FAIL $MODE missing marker"; FAILS=$((FAILS+1)); return; fi
    elif echo "$OUTPUT" | grep -q LDLOGIN_LAUNCH_SENT; then echo "FAIL $MODE false success"; FAILS=$((FAILS+1)); return
    fi
    echo "PASS $MODE"
}
run_case ok 0
run_case alreadyrunning 0
run_case noroot 10
run_case missing 11
run_case foreign 11
run_case malformed 11
run_case startfail 13
run_case errorzero 13
run_case exception 13
echo "Failures: $FAILS"
exit "$FAILS"
'@
$program=$header.Replace('__ROOT__',$root).Replace('__SCRIPT__',$script)
$program.Replace("`r`n","`n") | & $Adb -s $Serial shell sh
if ($LASTEXITCODE -ne 0) { throw "Game launch fixture failed (exit $LASTEXITCODE)" }
