# LDMenu v1.2 build

The ARM wrapper is built from `tests/ldmenu_arm_shim2.cpp` and its bounded helper
headers. It embeds `native/original/arm64-v8a.so`, retained from the existing
LDMenu binary. This is not recovery of the original module's C++ project.

Run `build.ps1 -NdkRoot <Android-NDK>` from this directory. The script requires
the pinned original hash, builds an API28 ARM64 Release wrapper and strips it.
Generated `module/zygisk/arm64-v8a.so` is ignored by Git; the ZIP is a release asset.

To package the pair, build LDLogin with its own build script and obtain the
original base ZIP from the existing v1.0.7 release:

`https://github.com/oneone404/ldmask/releases/download/v1.0.7/Module.zip`

The packager checks SHA256
`5478987117093abe95cf8d7532e6005cd88f75d3f6b913418ed9f419b73ed22c`.
Pass its local path explicitly:

```powershell
./tools/package-modules.ps1 -OutputDirectory <new-output-directory> -LDMenuBase <Module.zip>
```

The x86_64 payload remains unchanged; ARM uses the newly built wrapper. Pair
LDMenu v1.2 with LDMask v1.0.14 native core, not only its installed manager APK.
Read `tests/VERIFICATION-v1.0.14.md` and release notes for validation limits.
