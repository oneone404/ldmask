param([string]$BaseZip='D:\App\artifacts\ldmask-v1.0.5\OneOne.zip', [Parameter(Mandatory=$true)][string]$OutputZip)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$expected='0D852855A0D71884D8CA1E47B7CB68BA9F6B872210F7E5D051F07F0EC9D4BA2F'
if ((Get-FileHash -LiteralPath $BaseZip -Algorithm SHA256).Hash -ne $expected) { throw 'Unrecognized base ZIP' }
if (Test-Path -LiteralPath $OutputZip) { throw 'Refusing to overwrite output ZIP' }
Copy-Item -LiteralPath $BaseZip -Destination $OutputZip
$archive=[IO.Compression.ZipFile]::Open($OutputZip,[IO.Compression.ZipArchiveMode]::Update)
try {
    $prop=$archive.GetEntry('module.prop')
    $reader=New-Object IO.StreamReader($prop.Open())
    try { $text=$reader.ReadToEnd() } finally { $reader.Dispose() }
    $text=$text.Replace('version=v1.22','version=v1.23').Replace('versionCode=23','versionCode=24')
    $prop.Delete()
    $writer=New-Object IO.StreamWriter($archive.CreateEntry('module.prop').Open(),(New-Object Text.UTF8Encoding($false)))
    try { $writer.Write($text) } finally { $writer.Dispose() }
    if ($archive.GetEntry('ui.json')) { throw 'Base already has descriptor' }
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $PSScriptRoot '../module-ui/oneone.json'),'ui.json') | Out-Null
} finally { $archive.Dispose() }
Get-FileHash -LiteralPath $OutputZip -Algorithm SHA256
