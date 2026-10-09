param(
    [ValidateSet('127.0.0.1:5557')][string]$Serial = '127.0.0.1:5557',
    [ValidateRange(1, 10)][int]$Count = 5
)
# Destructive to only the running VNG process, not game/account data. Run only
# on the authorized comparison LD1, with native Hide enabled and no hide module.
$ErrorActionPreference = 'Stop'
$adb = 'D:\LDPlayer\LDPlayer9\adb.exe'
function Root([string]$Script) {
    $Script.Replace("`r`n", "`n") | & $adb -s $Serial shell 'su -c /system/bin/sh'
    if ($LASTEXITCODE -ne 0) { throw 'Root diagnostic failed' }
}
Root @'
set -eu
magisk --sqlite 'SELECT value FROM settings WHERE key="magiskhide";' | grep -q 'value=1'
magisk --sqlite 'SELECT value FROM settings WHERE key="zygisk";' | grep -q 'value=1'
for m in zygisk-assistant zygisk_shamiko; do
 [ ! -f /data/adb/modules/$m/module.prop ] || [ -f /data/adb/modules/$m/disable ]
done
echo BOOT=$(cat /proc/sys/kernel/random/boot_id)
magisk -v
'@
for ($run = 1; $run -le $Count; $run++) {
    Root 'am force-stop com.vng.playtogether'
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $start = & $adb -s $Serial shell am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n com.vng.playtogether/com.google.firebase.MessagingUnityPlayerActivity
    if ($LASTEXITCODE -ne 0) { throw 'Launcher command failed' }
    Write-Output "RUN=$run START=$($start -join ' ')"
    $ready = Root @'
n=0; last=''
while [ "$n" -lt 12 ]; do
 p=$(pidof com.vng.playtogether); p=${p%% *}
 d=$(dumpsys activity activities)
 if [ -n "$p" ] && echo "$d" | grep -q "app=ProcessRecord{.* $p:com.vng.playtogether/" && echo "$d" | grep -q 'ResumedActivity:.*com.vng.playtogether/'; then
  if [ "$p" = "$last" ]; then echo READY=$p; exit 0; fi
  last=$p
 else last=''; fi
 n=$((n+1)); sleep 2
done
echo NOT_READY
exit 1
'@
    $clock.Stop()
    Write-Output "RUN=$run RESULT=$($ready -join ' ') SECONDS=$([math]::Round($clock.Elapsed.TotalSeconds,2))"
}
Root @'
p=$(pidof com.vng.playtogether); p=${p%% *}
echo FINAL_PID=$p
echo ===MOUNTS===
grep -Ei 'magisk|/data/adb|zygisk' /proc/$p/mountinfo
echo ===MAPS===
t=$(awk '/^TracerPid:/ {print $2}' /proc/$p/status)
for q in "$p" "$t"; do
 [ "$q" != 0 ] && [ -r /proc/$q/maps ] || continue
 echo PROCESS=$q
 grep -Ei 'jit-zygisk-cache|/data/adb/modules/ldmenu|ktools_loader' /proc/$q/maps | head -12
done
echo ===SU===
for f in /sbin/su /sbin/magisk /system/bin/su /system/xbin/su; do
 test -e /proc/$p/root$f && echo PRESENT=$f || echo ABSENT=$f
 test ! -L /proc/$p/root$f || { echo LINK=$f; readlink /proc/$p/root$f; }
done
echo ===START_TIMEOUTS===
logcat -b system -d -v brief -s ActivityManager | grep -E 'ProcessRecord.*com.vng.playtogether.*failed to attach|Killing.*com.vng.playtogether.*start timeout'
echo ===CRASH_MARKERS===
logcat -b crash -d -v brief | grep -E 'Fatal signal|Abort message|backtrace|SIGSEGV|com.vng.playtogether'
true
'@
