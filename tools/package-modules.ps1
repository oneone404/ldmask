param([Parameter(Mandatory=$true)][string]$OutputDirectory,
 [string]$LDMenuBase='D:\App\artifacts\ldmask-v1.0.7\Module.zip')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repo=Split-Path -Parent $PSScriptRoot
if((Get-FileHash -LiteralPath $LDMenuBase).Hash -ne '5478987117093ABE95CF8D7532E6005CD88F75D3F6B913418ED9F419B73ED22C'){throw 'Unexpected LDMenu binary base'}
$login=Join-Path $OutputDirectory 'LDLogin.zip'
$menu=Join-Path $OutputDirectory 'LDMenu.zip'
if((Test-Path -LiteralPath $login) -or (Test-Path -LiteralPath $menu)){throw 'Refusing to overwrite output ZIP'}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$source=Join-Path $repo 'module-src/ldlogin/module'
if(!(Test-Path -LiteralPath (Join-Path $source 'system/bin/ldlogin_finder'))){throw 'Build LDLogin finder first'}
$loginZip=[IO.Compression.ZipFile]::Open($login,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($file in Get-ChildItem -LiteralPath $source -Recurse -File){
  $relative=$file.FullName.Substring($source.Length+1).Replace('\','/')
  [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($loginZip,$file.FullName,$relative) | Out-Null
 }
}finally{$loginZip.Dispose()}
$before=[IO.Compression.ZipFile]::OpenRead($LDMenuBase)
$after=[IO.Compression.ZipFile]::Open($menu,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($entry in $before.Entries){
  if($entry.FullName -eq 'module.prop'){continue}
  $target=$after.CreateEntry($entry.FullName)
  if($entry.FullName.EndsWith('/')){continue}
  $reader=$entry.Open();$writer=$target.Open()
  try{$reader.CopyTo($writer)}finally{$reader.Dispose();$writer.Dispose()}
 }
 foreach($name in @('module.prop','customize.sh')){
  [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($after,(Join-Path $repo "module-src/ldmenu/module/$name"),$name) | Out-Null
 }
}finally{$before.Dispose();$after.Dispose()}
foreach($path in @($login,$menu)){
 [pscustomobject]@{asset=(Split-Path -Leaf $path);size=(Get-Item -LiteralPath $path).Length;sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()} | ConvertTo-Json -Compress
}
