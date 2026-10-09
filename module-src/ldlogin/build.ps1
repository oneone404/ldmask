param([string]$NdkRoot='D:\App\.tools\android-ndk-r30')
$ErrorActionPreference='Stop'
$compiler=Join-Path $NdkRoot 'toolchains/llvm/prebuilt/windows-x86_64/bin/x86_64-linux-android28-clang++.cmd'
$output=Join-Path $PSScriptRoot 'module/system/bin/ldlogin_finder'
& $compiler '-O3' '-DNDEBUG' '-std=c++17' '-static-libstdc++' '-fno-exceptions' '-fno-rtti' '-ffunction-sections' '-fdata-sections' '-Wl,--gc-sections' '-s' (Join-Path $PSScriptRoot 'native/ldlogin_finder.cpp') '-o' $output
if($LASTEXITCODE -ne 0){throw 'LDLogin native build failed'}
Get-FileHash -LiteralPath $output -Algorithm SHA256
