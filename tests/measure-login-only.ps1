param([string]$Adb='D:\LDPlayer\LDPlayer9\adb.exe', [string]$Serial='127.0.0.1:5555')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$root='/data/local/tmp/ldlogin-measure-'+[guid]::NewGuid().ToString('N')
& $Adb -s $Serial shell mkdir -m 700 $root
if($LASTEXITCODE){throw 'Scratch mkdir failed'}
try {
 & $Adb -s $Serial push (Join-Path $repo 'module-src/ldlogin/module/system/bin/ldlogin_finder') "$root/finder"
 if($LASTEXITCODE){throw 'Push finder failed'}
 & $Adb -s $Serial push (Join-Path $repo 'module-src/ldlogin/module/images') "$root/images"
 if($LASTEXITCODE){throw 'Push images failed'}
 & $Adb -s $Serial shell chmod 700 "$root/finder"
 if($LASTEXITCODE){throw 'Scratch chmod failed'}
 & $Adb -s $Serial shell wm size
 # No --click, shell input, app launch, configuration access, or image saved to disk.
 # Toybox time includes child CPU; Max RSS is the largest process, not tree sum.
 foreach($sample in 1..6) {
  "SAMPLE $sample"
  & $Adb -s $Serial shell "toybox time -v $root/finder --batch $root/images --login-only"
  if($LASTEXITCODE -notin @(0,1)){throw 'Finder measurement failed'}
  if($sample -lt 6){Start-Sleep -Seconds 5}
 }
} finally {
 if($root -notmatch '^/data/local/tmp/ldlogin-measure-[0-9a-f]{32}$'){throw 'Invalid cleanup target'}
 & $Adb -s $Serial shell rm -r -- $root
}
