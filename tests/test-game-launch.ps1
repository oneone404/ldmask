param([string]$Adb='D:\LDPlayer\LDPlayer9\adb.exe', [string]$Serial='127.0.0.1:5559')
$ErrorActionPreference='Stop'
# Mock ALL root/package/activity commands; never open or stop the real game.
$root='/data/local/tmp/ldmask-launch-fixture-'+[guid]::NewGuid().ToString('N')
$script=Get-Content -Raw (Join-Path $PSScriptRoot '../app/src/main/res/raw/ldmask_open_game.sh')
$script=$script.Replace('/proc/uptime',"$root/uptime").Replace('/data/adb/magisk/busybox timeout -s TERM -k 1 4','mock_bounded')
$header=@'
ROOT=__ROOT__
case "$ROOT" in /data/local/tmp/ldmask-launch-fixture-*) ;; *) exit 99 ;; esac
case "$ROOT" in *..*) exit 99 ;; esac
mkdir -p "$ROOT" || exit 99
cleanup_fixture() { [ ! -L "$ROOT" ] && rm -rf -- "$ROOT"; }
trap cleanup_fixture EXIT
FAILS=0
run_case() {
    MODE=$1; EXPECTED=$2; EXPECT_START=$3; EXPECT_STOP=$4
    : > "$ROOT/trace"; echo 0 > "$ROOT/starts"; echo 0 > "$ROOT/stops"; echo 0 > "$ROOT/dumps"
    echo '0.00 0.00' > "$ROOT/uptime"
    case "$MODE" in
        alreadyrunning|focusfail|focusfail_then_disappear) echo background > "$ROOT/phase" ;;
        stuck|became_running|dumpfail|unknown_format|stopfail) echo starting > "$ROOT/phase" ;;
        *) echo absent > "$ROOT/phase" ;;
    esac
    OUTPUT=$(
        id() { if [ "$MODE" = noroot ]; then echo 2000; else echo 0; fi; }
        mock_bounded() { "$@"; }
        sleep() {
            IFS=' .' read -r NOW REST < "$ROOT/uptime"
            printf '%s.00 0.00\n' "$((NOW + $1))" > "$ROOT/uptime"
        }
        pidof() { [ "$(cat "$ROOT/phase")" = absent ] || echo 400; }
        dumpsys() {
            COUNT=$(($(cat "$ROOT/dumps") + 1)); echo "$COUNT" > "$ROOT/dumps"
            [ "$MODE" != dumpfail ] || return 1
            if [ "$MODE" = became_running ] && [ "$COUNT" = 2 ]; then echo background > "$ROOT/phase"; fi
            if [ "$MODE" = unknown_format ]; then echo 'Unknown activity output'; return 0; fi
            PHASE=$(cat "$ROOT/phase")
            if [ "$PHASE" = absent ]; then echo 'ACTIVITY MANAGER ACTIVITIES'; return 0; fi
            echo '* Hist #0: ActivityRecord{ab u0 com.vng.playtogether/.Main t3}'
            case "$PHASE" in
                starting) echo '  app=null'; echo '  state=INITIALIZING stopped=false' ;;
                *)
                    echo '  app=ProcessRecord{cd 400:com.vng.playtogether/u0a63}'
                    if [ "$PHASE" = ready ]; then
                        echo '  state=RESUMED stopped=false'
                        echo 'ResumedActivity: ActivityRecord{ab u0 com.vng.playtogether/.Main t3}'
                    else echo '  state=STOPPED stopped=true'; fi ;;
            esac
        }
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
            if [ "$1" = force-stop ]; then
                COUNT=$(($(cat "$ROOT/stops") + 1)); echo "$COUNT" > "$ROOT/stops"
                [ "$MODE" != stopfail ] || return 1
                echo absent > "$ROOT/phase"; return 0
            fi
            COUNT=$(($(cat "$ROOT/starts") + 1)); echo "$COUNT" > "$ROOT/starts"
            case "$MODE" in
                startfail) echo 'Error: Activity not started'; return 1 ;;
                errorzero) echo 'Error: Permission denied'; return 0 ;;
                exception) echo 'java.lang.SecurityException'; return 0 ;;
                failattach) echo starting > "$ROOT/phase" ;;
                recover) if [ "$COUNT" = 1 ]; then echo starting > "$ROOT/phase"; else echo ready > "$ROOT/phase"; fi ;;
                focusfail) echo background > "$ROOT/phase" ;;
                focusfail_then_disappear) if [ "$COUNT" = 1 ]; then echo background > "$ROOT/phase"; else echo absent > "$ROOT/phase"; fi ;;
                dumpfail|unknown_format) : ;;
                *) echo ready > "$ROOT/phase" ;;
            esac
            echo 'Starting: Intent { mock }'; return 0
        }
        __SCRIPT__
    )
    STATUS=$?
    if [ "$STATUS" != "$EXPECTED" ]; then echo "FAIL $MODE status=$STATUS"; FAILS=$((FAILS+1)); return; fi
    if [ "$(cat "$ROOT/starts")" != "$EXPECT_START" ] || [ "$(cat "$ROOT/stops")" != "$EXPECT_STOP" ]; then
        echo "FAIL $MODE starts=$(cat "$ROOT/starts") stops=$(cat "$ROOT/stops")"; FAILS=$((FAILS+1)); return
    fi
    if grep '^am ' "$ROOT/trace" | grep -vE '^am (start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n com.vng.playtogether/com.google.firebase.MessagingUnityPlayerActivity|force-stop com.vng.playtogether)$'; then
        echo "FAIL $MODE foreign action"; FAILS=$((FAILS+1)); return
    fi
    if [ "$EXPECTED" = 0 ]; then
        if [ "$OUTPUT" != LDLOGIN_GAME_READY ]; then echo "FAIL $MODE missing marker"; FAILS=$((FAILS+1)); return; fi
    elif echo "$OUTPUT" | grep -q LDLOGIN_GAME_READY; then echo "FAIL $MODE false success"; FAILS=$((FAILS+1)); return
    fi
    echo "PASS $MODE"
}
run_case ok 0 1 0
run_case alreadyrunning 0 1 0
run_case stuck 0 1 1
run_case recover 0 2 1
run_case became_running 0 1 0
run_case focusfail 13 3 0
run_case focusfail_then_disappear 13 3 0
run_case failattach 13 3 2
run_case dumpfail 13 3 0
run_case unknown_format 13 3 0
run_case stopfail 13 0 1
run_case noroot 10 0 0
run_case missing 11 0 0
run_case foreign 11 0 0
run_case malformed 11 0 0
run_case startfail 13 3 2
run_case errorzero 13 3 2
run_case exception 13 3 2
echo "Failures: $FAILS"
exit "$FAILS"
'@
$program=$header.Replace('__ROOT__',$root).Replace('__SCRIPT__',$script)
$program.Replace("`r`n","`n") | & $Adb -s $Serial shell sh
if ($LASTEXITCODE -ne 0) { throw "Game launch fixture failed (exit $LASTEXITCODE)" }
