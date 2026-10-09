param([string]$NdkRoot='D:\App\.tools\kitsune-sdk\ndk\magisk')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$original=Join-Path $PSScriptRoot 'native/original/arm64-v8a.so'
if(!(Test-Path -LiteralPath $original) -or (Get-FileHash -LiteralPath $original).Hash -ne 'ECD058D4B55C2C983152F31245285C9159C0895EE987ADE5AE9438AF1DCECAAF'){
 throw 'Missing or unexpected original ARM dependency; do not substitute arbitrary binaries'
}
$bin=Join-Path $NdkRoot 'toolchains/llvm/prebuilt/windows-x86_64/bin'
$output=Join-Path $PSScriptRoot 'module/zygisk/arm64-v8a.so'
New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null
Push-Location -LiteralPath $repo
try {
 & (Join-Path $bin 'aarch64-linux-android28-clang++.cmd') -std=c++17 -O2 -DNDEBUG -DLDMENU_SHIM_RELEASE -fPIC -shared -fno-exceptions -fno-rtti -static-libstdc++ tests/ldmenu_arm_shim2.cpp module-src/ldmenu/native/embedded.S '-Wl,-z,relro,-z,now' '-Wl,-soname,libjit-loader.so' -ldl -llog -o $output
 if($LASTEXITCODE -ne 0){throw 'LDMenu ARM release build failed'}
 & (Join-Path $bin 'llvm-strip.exe') $output
 if($LASTEXITCODE -ne 0){throw 'LDMenu ARM strip failed'}
}finally{Pop-Location}
Get-FileHash -LiteralPath $output -Algorithm SHA256
