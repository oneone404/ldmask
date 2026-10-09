# LDMask v1.0.14 / LDMenu v1.2 — local release build

Date: 2026-10-10, Asia/Bangkok. Build/package only in this turn; no live LD installation, reboot, GitHub publication or source-recovery claim.

## Build

- Full `build.py -v -c config.ldmask.prop -r all` succeeded: native binaries for four ABIs, app and stub. APK includes all four ABI core libraries.
- Generated flags: MAGISK_VERSION=LDMask-1.0.14, MAGISK_VER_CODE=27016, MAGISK_DEBUG=0, LDMENU_LOADER_EXPERIMENT=1. LDMENU_HIDE_EXPERIMENT and LDMENU_TRACE_EXPERIMENT absent. The test-only ptrace hook is excluded.
- LDMenu ARM wrapper rebuilt with API28 Clang, C++17/O2/NDEBUG/LDMENU_SHIM_RELEASE, stripped. Diagnostic audit calls compile out. Original ARM dependency hash pinned; not recovered original project source.
- `tools/package-modules.ps1` includes the new ARM wrapper and verifies ELF architecture. LDMenu x86_64 remains byte-identical to the original pinned ZIP; LDLogin runtime unchanged.
- Pre-existing toolchain/compiler warnings remain; build success is not a full security audit.

## Validation

- 54 JVM tests, 0 failures/errors/skips, including `validatesActualReleaseZipPair` with LDMASK_RELEASE_FILES pointing at this bundle. Production validation assertions unchanged.
- `git diff --check` passed.
- apksigner verify succeeded. Certificate SHA256 `dc0754b98e885c80916f5da9eea6ea2aacc2f1f22e09040f4debafbd3c8a2621`, identical to v1.0.13. Existing Android Debug certificate retained; Release optimization does not imply a dedicated public-release signing key.
- aapt package: io.github.oneone404.ldmask, LDMask-1.0.14 / 27016, label LDMask. Bundled util_functions.sh agrees with version/code.
- APK size 12,888,958 bytes; SHA256 `5c55d2c8d000f2c0286a586bf8a5f4759e7dc7c06ba2656facf77d81d82193e0`.
- LDMenu.zip: v1.2 / 3, 3,103,489 bytes; SHA256 `aa660113a218ee206e16346c78cd9853222efcb63dbde6f13e4e6f9257311cdf`.
- LDLogin.zip: v1.24 / 25, 158,645 bytes; SHA256 `8c72c673bc1820488db014ad500ac1ed791dc74d0c92cbb1807c4a571377b70c`.
- ARM wrapper: 3,347,712 bytes; SHA256 `265100e65058a6d13086b44956a9ed12e9f4f8bb0230be8c113a208d4053122d`.

APK packaged cores:

- x86: `779eaa9d3f11e39e464cc7e3280216bc65e0f178fe9b901895f1cd2ed9bb3760`.
- x86_64: `edcaba611a42919a75124791f85b925e5bdeaa7dc8131817a78093d8f04e5cc2`.
- ARM32: `e991e4a9115425202499b61a23df2229332f571abe98032506fd56676a92e90f`.
- ARM64: `5e262bc03e3d2de5bdbd40f2dfe6c41623dfb719e726f630e0a858543a01c9fa`.

## Live-test boundary

Earlier trial fixtures/runtime observations are recorded in VERIFICATION-arm-shim2-20261010.md and VERIFICATION-v1.0.13.md. Their results support reduced explicit LDMenu path/SONAME exposure and repaired native-Hide startup. They do not establish universal root invisibility, game/server detection outcome, or sustained stability for this rebuilt release.

APK installation alone does not update installed Magisk core or LDMenu. Direct-system core installation, new LDMenu ZIP and explicit LD reboot are needed. The remote Quick Install catalog remains unchanged until publication.
