param([string]$Adb='D:\LDPlayer\LDPlayer9\adb.exe',[string]$Serial='emulator-5556')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
# This also creates deterministic LOGIN/CONFIRM/OK/BALO/MENU frames locally.
& (Join-Path $PSScriptRoot 'test-login-backpack-native.ps1') -Adb $Adb -Serial $Serial
$frames=Join-Path $repo 'app/build/backpack-native-fixture'
$root='/data/local/tmp/ldlogin-cache-fixture-'+[guid]::NewGuid().ToString('N')
& $Adb -s $Serial shell mkdir -m 700 $root
if($LASTEXITCODE){throw 'Cannot create cache fixture'}
try{
 foreach($file in @('ldlogin_finder','ldlogin_cache.sh','ldlogin_gate.sh')){
  & $Adb -s $Serial push (Join-Path $repo "module-src/ldlogin/module/system/bin/$file") "$root/$file"
  if($LASTEXITCODE){throw 'Fixture push failed'}
 }
 & $Adb -s $Serial push (Join-Path $repo 'module-src/ldlogin/module/images') "$root/images"
 if($LASTEXITCODE){throw 'Fixture images push failed'}
 foreach($tag in @('LOGIN','CONFIRM','OK','BALO','MENU')){
  & $Adb -s $Serial push (Join-Path $frames "$tag.png") "$root/$tag.png"
  if($LASTEXITCODE){throw 'Frame push failed'}
 }
 $program=@'
ROOT=__ROOT__
export ROOT
chmod 700 "$ROOT/ldlogin_finder"
cat > "$ROOT/finder" <<'WRAPPER'
#!/system/bin/sh
if [ "$1" = --batch-worker ]; then
    exec "$ROOT/ldlogin_finder" "$@" --screen "$ROOT/frame.png"
fi
exec "$ROOT/ldlogin_finder" "$@"
WRAPPER
chmod 700 "$ROOT/finder"
FINDER_V2="$ROOT/finder"; IMAGES_DIR="$ROOT/images"
. "$ROOT/ldlogin_gate.sh"
. "$ROOT/ldlogin_cache.sh"
log_msg() { :; }
trap 'cache_stop_worker; gate_stop_watcher' EXIT
FAILS=0
check() { if [ "$1" = 1 ]; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS+1)); fi; }
scan() {
    cp "$ROOT/$1.png" "$ROOT/frame.png"
    cache_login_scan || { echo "FAIL cache scan $1"; FAILS=$((FAILS+1)); return 1; }
    EXPECT="$1"; case "$1" in BALO|MENU) EXPECT=NOT_FOUND ;; esac
    case "$EXPECT:$CACHE_RESULT" in
      LOGIN:'FOUND LOGIN '*|CONFIRM:'FOUND CONFIRM '*|OK:'FOUND OK '*|NOT_FOUND:'NOT_FOUND '*) echo "PASS cached fresh frame $1" ;;
      *) echo "FAIL cached frame $1: $CACHE_RESULT"; FAILS=$((FAILS+1)) ;;
    esac
}
stats() { printf 'STATS\n' >&6; IFS= read -r -t 3 STATS <&7 || exit 30; }
scan LOGIN
FIRST_PID="$CACHE_PID"
stats
check "$([ "$STATS" = 'CACHE_STATS 3 0 3' ] && echo 1)" 'initial scan decodes exactly three templates'
scan LOGIN
stats
check "$([ "$STATS" = 'CACHE_STATS 3 3 3' ] && echo 1)" 'second scan uses all three cached templates'
for TAG in CONFIRM OK BALO MENU; do scan "$TAG"; done
check "$([ "$FIRST_PID" = "$CACHE_PID" ] && echo 1)" 'same worker survives all requests'
stats
check "$([ "$STATS" = 'CACHE_STATS 3 15 3' ] && echo 1)" 'six scans still decode only three templates'

cp "$ROOT/images/nut_dang_nhap.png" "$ROOT/original.png"
cp "$ROOT/images/nut_ok.png" "$ROOT/replacement.png"
mv "$ROOT/replacement.png" "$ROOT/images/nut_dang_nhap.png"
cp "$ROOT/LOGIN.png" "$ROOT/frame.png"
cache_login_scan || exit 31
case "$CACHE_RESULT" in 'NOT_FOUND '*) check 1 'atomic template replacement does not reuse old LOGIN';; *) check 0 'atomic replacement';; esac
stats
check "$([ "$STATS" = 'CACHE_STATS 4 17 3' ] && echo 1)" 'only changed template decoded again'
printf 'invalid PNG' > "$ROOT/images/nut_dang_nhap.png"
cache_login_scan || exit 32
case "$CACHE_RESULT" in 'NOT_FOUND '*) check 1 'corrupt template invalidates cached image';; *) check 0 'corrupt invalidation';; esac
rm -f "$ROOT/images/nut_dang_nhap.png"
cache_login_scan || exit 33
case "$CACHE_RESULT" in 'NOT_FOUND '*) check 1 'deleted template cannot match stale cache';; *) check 0 'deleted invalidation';; esac
cp "$ROOT/original.png" "$ROOT/images/nut_dang_nhap.png"
scan LOGIN
check "$([ "$FIRST_PID" = "$CACHE_PID" ] && echo 1)" 'restored template works without worker restart'
chmod 600 "$ROOT/images/nut_dang_nhap.png"
scan LOGIN
stats
check "$([ "$STATS" = 'CACHE_STATS 6 25 3' ] && echo 1)" 'metadata changes invalidate template snapshot'

# Both private FIFO pairs coexist; watcher must not inherit matcher pipe fds.
GATE_PATH="$ROOT/settings.json"
"$FINDER_V2" --save-settings "$GATE_PATH" 1 30 0 0 >/dev/null || exit 34
gate_start_watcher || exit 35
scan OK
check "$([ "$BOT_RUN_ALLOWED" = 1 ] && [ "$OPEN_BACKPACK" = 0 ] && echo 1)" 'cache coexists with config gate'
check "$([ ! -e "/proc/$GATE_WATCH_PID/fd/6" ] && [ ! -e "/proc/$GATE_WATCH_PID/fd/7" ] && echo 1)" 'watcher does not inherit matcher descriptors'
"$FINDER_V2" --save-settings "$GATE_PATH" 0 30 0 0 >/dev/null
wait_bot_gate 2
check "$([ "$BOT_RUN_ALLOWED" = 0 ] && echo 1)" 'master OFF event still arrives with cache running'

OLD_DIR="$CACHE_DIR"; OLD_PID="$CACHE_PID"
cache_stop_worker
check "$([ ! -d "$OLD_DIR" ] && [ -z "$CACHE_RESULT" ] && [ -z "$CACHE_PID" ] && echo 1)" 'stop clears cache IPC and pending result'
check "$([ ! -d "/proc/$OLD_PID" ] && echo 1)" 'stopped worker is reaped'
scan LOGIN
check "$([ "$CACHE_PID" != "$OLD_PID" ] && echo 1)" 'cache starts afresh after stop'
stats
check "$([ "$STATS" = 'CACHE_STATS 3 0 3' ] && echo 1)" 'restart has no stale template cache'

kill -KILL "$CACHE_PID"; wait "$CACHE_PID" 2>/dev/null
scan CONFIRM
check "$([ "$CACHE_PID" != "$OLD_PID" ] && echo 1)" 'dead worker recovers on next request'
rm -f "$ROOT/frame.png"
if cache_login_scan; then check 0 'capture error rejected'; else check 1 'capture error rejects and clears worker'; fi
check "$([ -z "$CACHE_RESULT" ] && [ -z "$CACHE_PID" ] && echo 1)" 'failed capture cannot reuse old match'
scan OK

# Idle worker must not scan/capture without another request.
stats; BEFORE="$STATS"
sleep 1
stats
check "$([ "$BEFORE" = "$STATS" ] && echo 1)" 'idle worker performs no additional scans'
grep -E '^(VmRSS|RssAnon):' "/proc/$CACHE_PID/status"

kill -STOP "$CACHE_PID"
if cache_login_scan; then check 0 'timeout rejected'; else check 1 'timed-out worker is discarded'; fi
check "$([ -z "$CACHE_RESULT" ] && [ -z "$CACHE_PID" ] && echo 1)" 'timeout cannot reuse pending result'
scan LOGIN
cache_stop_worker
gate_stop_watcher

# Parent-death guard: a synthetic owner exits, and its private worker must die.
mkdir -m 700 "$ROOT/owner"
mkfifo -m 600 "$ROOT/owner/requests" "$ROOT/owner/results"
cat > "$ROOT/owner.sh" <<'OWNER'
#!/system/bin/sh
exec 6<>"$ROOT/owner/requests" 7<>"$ROOT/owner/results"
"$ROOT/ldlogin_finder" --batch-worker "$ROOT/images" $$ 6>&- 7<&- <"$ROOT/owner/requests" >"$ROOT/owner/results" &
CHILD=$!
echo "$CHILD" > "$ROOT/owner/child"
IFS= read -r -t 3 READY <&7 || exit 40
[ "$READY" = CACHE_READY ] || exit 41
echo ready > "$ROOT/owner/ready"
IFS= read -r -t 15 UNBLOCK <&6
OWNER
sh "$ROOT/owner.sh" &
OWNER_PID=$!
N=0
while [ ! -f "$ROOT/owner/ready" ] && [ "$N" -lt 40 ]; do sleep 0.05; N=$((N+1)); done
if [ -f "$ROOT/owner/ready" ]; then
    CHILD_PID=$(cat "$ROOT/owner/child")
    kill -KILL "$OWNER_PID"; wait "$OWNER_PID" 2>/dev/null
    N=0; ALIVE=1
    while [ "$N" -lt 40 ]; do
        if [ ! -f "/proc/$CHILD_PID/stat" ]; then ALIVE=0; break; fi
        IFS=' ' read -r PID COMM STATE REST < "/proc/$CHILD_PID/stat"
        case "$STATE" in Z|X|x) ALIVE=0; break ;; esac
        sleep 0.05; N=$((N+1))
    done
    check "$([ "$ALIVE" = 0 ] && echo 1)" 'parent death terminates idle worker'
else
    kill -KILL "$OWNER_PID" 2>/dev/null; wait "$OWNER_PID" 2>/dev/null
    check 0 'parent-death fixture startup'
fi
echo "Failures: $FAILS"
exit "$FAILS"
'@
 $program.Replace('__ROOT__',$root).Replace("`r`n","`n") | & $Adb -s $Serial shell sh
 if($LASTEXITCODE){throw "Cache fixture failed ($LASTEXITCODE)"}
}finally{
 if($root -notmatch '^/data/local/tmp/ldlogin-cache-fixture-[a-f0-9]{32}$'){throw 'Invalid fixture cleanup path'}
 & $Adb -s $Serial shell "[ ! -L '$root' ] && rm -rf -- '$root'"
}
