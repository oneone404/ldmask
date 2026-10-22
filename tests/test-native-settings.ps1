param([string]$ModuleZip='D:\App\artifacts\ldmask-v1.0.8\LDLogin.zip',
    [string]$Adb='D:\LDPlayer\LDPlayer9\adb.exe', [string]$Serial='127.0.0.1:5559')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root='/data/local/tmp/ldmask-settings-fixture-'+[guid]::NewGuid().ToString('N')
$local=Join-Path $PSScriptRoot '../app/build/native-settings-fixture'
New-Item -ItemType Directory -Force $local | Out-Null
$finder=Join-Path $local 'ldlogin_finder'
$zip=[IO.Compression.ZipFile]::OpenRead($ModuleZip)
try { [IO.Compression.ZipFileExtensions]::ExtractToFile($zip.GetEntry('system/bin/ldlogin_finder'),$finder,$true) }
finally { $zip.Dispose() }
& $Adb -s $Serial shell mkdir -p $root
if ($LASTEXITCODE) { throw 'Fixture mkdir failed' }
try {
    & $Adb -s $Serial push $finder "$root/finder"
    if ($LASTEXITCODE) { throw 'Fixture push failed' }
    $program=@'
ROOT=__ROOT__
case "$ROOT" in /data/local/tmp/ldmask-settings-fixture-*) ;; *) exit 9 ;; esac
case "$ROOT" in *..*) exit 9 ;; esac
cleanup() { [ ! -L "$ROOT" ] && rm -rf -- "$ROOT"; }
trap cleanup EXIT
chmod 700 "$ROOT/finder"
FILE="$ROOT/settings.json"
RESULT=$("$ROOT/finder" --settings "$FILE"); STATUS=$?
[ "$STATUS" = 3 ] && [ "$RESULT" = 'SETTINGS 0 30 0' ] || exit 1
echo 'PASS missing settings defaults OFF/30/no-log'
"$ROOT/finder" --save-settings "$FILE" 0 75 1 || exit 2
RESULT=$("$ROOT/finder" --settings "$FILE") || exit 3
[ "$RESULT" = 'SETTINGS 0 75 1' ] || exit 4
echo 'PASS native writer round-trip'
"$ROOT/finder" --save-settings "$FILE" 1 601 1; STATUS=$?
[ "$STATUS" != 0 ] && [ "$("$ROOT/finder" --settings "$FILE")" = 'SETTINGS 0 75 1' ] || exit 5
echo 'PASS invalid range preserves existing file'
rm -f -- "$FILE"
printf sentinel > "$ROOT/sentinel"
ln -s "$ROOT/sentinel" "$FILE"
"$ROOT/finder" --save-settings "$FILE" 1 30 0; STATUS=$?
[ "$STATUS" != 0 ] && [ "$(cat "$ROOT/sentinel")" = sentinel ] || exit 6
echo 'PASS symlink writer refusal'
rm -f -- "$FILE"
printf '{"enabled":true,"boot_wait_seconds":"oops"}' > "$FILE"
RESULT=$("$ROOT/finder" --settings "$FILE"); STATUS=$?
[ "$STATUS" = 3 ] && [ "$RESULT" = 'SETTINGS 0 30 0' ] || exit 7
echo 'PASS malformed settings fail closed'
printf '{"enabled":true,"boot_wait_seconds":45,"logging":false}' > "$FILE"
[ "$("$ROOT/finder" --settings-v2 "$FILE")" = 'SETTINGS 1 45 0 0' ] || exit 8
echo 'PASS enabling LDLogin alone defaults FramLogin OFF'
"$ROOT/finder" --save-settings "$FILE" 1 45 0 0 || exit 10
[ "$("$ROOT/finder" --settings-v2 "$FILE")" = 'SETTINGS 1 45 0 0' ] || exit 11
echo 'PASS backpack OFF round-trip'
"$ROOT/finder" --save-settings "$FILE" 1 60 1 || exit 12
[ "$("$ROOT/finder" --settings-v2 "$FILE")" = 'SETTINGS 1 60 1 0' ] || exit 13
echo 'PASS old-manager writer preserves backpack OFF'
"$ROOT/finder" --save-settings "$FILE" 1 60 1 1 || exit 14
[ "$("$ROOT/finder" --settings-v2 "$FILE")" = 'SETTINGS 1 60 1 1' ] || exit 15
echo 'PASS backpack ON round-trip'
"$ROOT/finder" --save-settings "$FILE" 1 60 1 2; STATUS=$?
[ "$STATUS" != 0 ] && [ "$("$ROOT/finder" --settings-v2 "$FILE")" = 'SETTINGS 1 60 1 1' ] || exit 16
echo 'PASS invalid switch preserves saved settings'
printf '{"enabled":true,"open_backpack":"false"}' > "$FILE"
RESULT=$("$ROOT/finder" --settings-v2 "$FILE"); STATUS=$?
[ "$STATUS" = 3 ] && [ "$RESULT" = 'SETTINGS 0 30 0 0' ] || exit 17
echo 'PASS wrong-type backpack fails closed'
"$ROOT/finder" --save-settings "$FILE" 0 30 0 1 || exit 18
[ "$("$ROOT/finder" --settings-v2 "$FILE")" = 'SETTINGS 0 30 0 0' ] || exit 19
echo 'PASS native writer cannot enable FramLogin with LDLogin OFF'
"$ROOT/finder" --save-settings "$FILE" 1 30 0 || exit 20
[ "$("$ROOT/finder" --settings-v2 "$FILE")" = 'SETTINGS 1 30 0 0' ] || exit 21
echo 'PASS master re-enable does not restart FramLogin'
printf '{"enabled":false,"open_backpack":true}' > "$FILE"
[ "$("$ROOT/finder" --settings-v2 "$FILE")" = 'SETTINGS 0 30 0 0' ] || exit 22
echo 'PASS native reader rejects orphan FramLogin enable'
'@
    $program.Replace('__ROOT__',$root) | & $Adb -s $Serial shell sh
    if ($LASTEXITCODE) { throw 'Native settings fixture failed' }
} finally {
    # Exact generated test directory only, never the real module/settings directory.
    & $Adb -s $Serial shell "[ ! -L '$root' ] && rm -rf -- '$root'"
}
