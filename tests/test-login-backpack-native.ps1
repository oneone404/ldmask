param([string]$Adb='D:\LDPlayer\LDPlayer9\adb.exe', [string]$Serial='emulator-5554')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$local=Join-Path $repo 'app/build/backpack-native-fixture'
New-Item -ItemType Directory -Path $local -Force | Out-Null
Add-Type -AssemblyName System.Drawing
# Generated screenshots contain only public module template assets, never real account/game frames.
$cases=@(
 @{Tag='BALO';File='nut_balo.png';X=910;Y=310},
 @{Tag='MENU';File='tat_menu.png';X=745;Y=100},
 @{Tag='LOGIN';File='nut_dang_nhap.png';X=480;Y=190},
 @{Tag='CONFIRM';File='nut_xac_nhan.png';X=590;Y=410},
 @{Tag='OK';File='nut_ok.png';X=480;Y=410}
)
foreach($case in $cases){
 $template=[Drawing.Bitmap]::new((Join-Path $repo ('module-src/ldlogin/module/images/'+$case.File)))
 $screen=[Drawing.Bitmap]::new(960,540,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $graphics=[Drawing.Graphics]::FromImage($screen)
 try{
  $graphics.Clear([Drawing.Color]::FromArgb(255,117,83,153))
  # Copy pixels explicitly: GDI DrawImageUnscaled may still apply PNG DPI/alpha
  # transformations, which would make this an inexact matcher fixture.
  $left=$case.X-[int][Math]::Floor($template.Width/2)
  $top=$case.Y-[int][Math]::Floor($template.Height/2)
  for($y=0;$y -lt $template.Height;$y++){
   for($x=0;$x -lt $template.Width;$x++){$screen.SetPixel(($left+$x),($top+$y),$template.GetPixel($x,$y))}
  }
  $screen.Save((Join-Path $local ($case.Tag+'.png')),[Drawing.Imaging.ImageFormat]::Png)
 }finally{$graphics.Dispose();$screen.Dispose();$template.Dispose()}
}
$root='/data/local/tmp/ldlogin-native-fixture-'+[guid]::NewGuid().ToString('N')
& $Adb -s $Serial shell mkdir -m 700 $root
if($LASTEXITCODE){throw 'Fixture mkdir failed'}
try{
 & $Adb -s $Serial push (Join-Path $repo 'module-src/ldlogin/module/system/bin/ldlogin_finder') "$root/finder"
 if($LASTEXITCODE){throw 'Push finder failed'}
 & $Adb -s $Serial push (Join-Path $repo 'module-src/ldlogin/module/system/bin/ldlogin_gate.sh') "$root/gate.sh"
 if($LASTEXITCODE){throw 'Push gate failed'}
 & $Adb -s $Serial push (Join-Path $repo 'module-src/ldlogin/module/images') "$root/images"
 if($LASTEXITCODE){throw 'Push images failed'}
 foreach($case in $cases){
  & $Adb -s $Serial push (Join-Path $local ($case.Tag+'.png')) "$root/$($case.Tag).png"
  if($LASTEXITCODE){throw 'Push generated frame failed'}
 }
 $program=@'
ROOT=__ROOT__
chmod 700 "$ROOT/finder"
FAILS=0
for TAG in BALO MENU LOGIN CONFIRM OK; do
 RESULT=$("$ROOT/finder" --batch "$ROOT/images" --screen "$ROOT/$TAG.png")
 case "$RESULT" in "FOUND $TAG "*) echo "PASS native default matches $TAG" ;; *) echo "FAIL default $TAG: $RESULT"; FAILS=$((FAILS+1)) ;; esac
 RESULT=$("$ROOT/finder" --batch "$ROOT/images" --screen "$ROOT/$TAG.png" --login-only)
 case "$TAG:$RESULT" in BALO:NOT_FOUND*|MENU:NOT_FOUND*|CONFIRM:'FOUND CONFIRM '*|OK:'FOUND OK '*|LOGIN:'FOUND LOGIN '*) echo "PASS native login-only $TAG" ;; *) echo "FAIL login-only $TAG: $RESULT"; FAILS=$((FAILS+1)) ;; esac
done
FILE="$ROOT/settings.json"
"$ROOT/finder" --save-settings "$FILE" 1 30 0 1 >/dev/null || exit 20
"$ROOT/finder" --watch-config "$FILE" $$ > "$ROOT/frames" &
WATCH=$!
wait_frame() {
 N=0
 while [ "$N" -lt 40 ]; do
  LAST=$(tail -n 1 "$ROOT/frames")
  if echo "$LAST" | grep -q "$1"; then return 0; fi
  sleep 0.05; N=$((N+1))
 done
 echo "FAIL watcher frame: $LAST"; FAILS=$((FAILS+1)); return 1
}
wait_frame '^STATE2 [0-9]* [0-9]* 1 [0-9]* 0 1$' && echo 'PASS watcher initial backpack ON'
"$ROOT/finder" --save-settings "$FILE" 1 30 0 0 >/dev/null
wait_frame '^STATE2 [0-9]* [0-9]* 1 [0-9]* 0 0$' && echo 'PASS inotify publishes backpack-only OFF change'
"$ROOT/finder" --save-settings "$FILE" 1 30 0 1 >/dev/null
wait_frame '^STATE2 [0-9]* [0-9]* 1 [0-9]* 0 1$' && echo 'PASS inotify publishes backpack-only ON change'
printf '{"enabled":true,"open_backpack":"bad"}' > "$FILE"
wait_frame '^STATE2 [0-9]* [0-9]* 0 [0-9]* 0 0$' && echo 'PASS watcher malformed settings shuts bot and FramLogin OFF'
kill "$WATCH"; wait "$WATCH"
. "$ROOT/gate.sh"
log_msg() { :; }
trap 'gate_stop_watcher' EXIT
"$ROOT/finder" --save-settings "$FILE" 1 30 0 1 >/dev/null
FINDER_V2="$ROOT/finder"; GATE_PATH="$FILE"
if gate_start_watcher && [ "$BOT_RUN_ALLOWED" = 1 ] && [ "$OPEN_BACKPACK" = 1 ]; then echo 'PASS real shell gate accepts STATE2'; else FAILS=$((FAILS+1)); echo 'FAIL shell gate initial state'; fi
"$ROOT/finder" --save-settings "$FILE" 1 30 0 0 >/dev/null
wait_bot_gate 2
if [ "$BOT_RUN_ALLOWED" = 1 ] && [ "$OPEN_BACKPACK" = 0 ]; then echo 'PASS shell gate changes backpack without disabling login'; else FAILS=$((FAILS+1)); echo 'FAIL shell gate backpack OFF'; fi
"$ROOT/finder" --save-settings "$FILE" 1 30 0 1 >/dev/null
wait_bot_gate 2
if [ "$BOT_RUN_ALLOWED" = 1 ] && [ "$OPEN_BACKPACK" = 1 ]; then echo 'PASS shell gate re-enables backpack'; else FAILS=$((FAILS+1)); echo 'FAIL shell gate backpack ON'; fi
"$ROOT/finder" --save-settings "$FILE" 0 30 0 0 >/dev/null
wait_bot_gate 2
if [ "$BOT_RUN_ALLOWED" = 0 ] && [ "$OPEN_BACKPACK" = 0 ]; then echo 'PASS shell gate disables bot safely'; else FAILS=$((FAILS+1)); echo 'FAIL shell gate bot OFF'; fi
"$ROOT/finder" --save-settings "$FILE" 1 30 0 >/dev/null
wait_bot_gate 2
if [ "$BOT_RUN_ALLOWED" = 1 ] && [ "$OPEN_BACKPACK" = 0 ]; then echo 'PASS re-enabling LDLogin leaves FramLogin OFF'; else FAILS=$((FAILS+1)); echo 'FAIL implicit FramLogin re-enable'; fi
gate_clock
GATE_MSG_TAG=STATE2; GATE_MSG_PID="$GATE_WATCH_PID"; GATE_MSG_SEQ=$((GATE_SEQUENCE+1))
GATE_MSG_TIME="$GATE_NOW"; GATE_MSG_VALUE=0; GATE_MSG_LOG=0; GATE_MSG_BACKPACK=1; GATE_MSG_EXTRA=''
gate_accept_frame
if [ "$BOT_RUN_ALLOWED" = 0 ] && [ "$OPEN_BACKPACK" = 0 ]; then echo 'PASS shell blocks orphan FramLogin even with inconsistent frame'; else FAILS=$((FAILS+1)); echo 'FAIL inconsistent frame enabled FramLogin'; fi
gate_stop_watcher
echo "Failures: $FAILS"
exit "$FAILS"
'@
 $program.Replace('__ROOT__',$root).Replace("`r`n","`n") | & $Adb -s $Serial shell sh
 if($LASTEXITCODE){throw "Native backpack fixture failed ($LASTEXITCODE)"}
}finally{
 # Validated, unique scratch directory only; no production modules or settings.
 if($root -notmatch '^/data/local/tmp/ldlogin-native-fixture-[a-f0-9]{32}$'){throw 'Invalid cleanup path'}
 & $Adb -s $Serial shell "[ ! -L '$root' ] && rm -rf -- '$root'"
}
