# v1.0.0 verification — 2026-10-09

- Full release-mode build: passed (native binaries for four ABIs + APK + stub).
- Final app-only release rebuild after UI changes: passed.
- JVM suite: 14 tests, zero skipped/failures/errors, including validation of the
  actual OneOne and ktools ZIPs listed in `releases/v1.0.0/modules.json`.
- APK package `io.github.oneone404.ldmask`, label `LDMask`, version
  `LDMask-1.0.0`, code 27002, min SDK 23, target SDK 34; not debuggable.
- Native default manager identity and version strings inspected in x86_64
  `magisk`; installer util_functions.sh version/code match the APK.
- APK has all 20 native binaries. SHA-256 of each packaged entry matches the
  corresponding Gradle stripped-native output (release stripping intentionally
  differs from some unstripped files in native/out).
- APK v1/v2 signatures verified; local Android debug certificate.
- Final APK: 12,888,683 bytes, SHA-256
  `ec11527c80bb2aea9d70570b467a30cbb57502df7c790872ae833cdc5cce6cd8`.
- Git diff whitespace checks passed.

The user tested root successfully with the prior unmodified baseline APK.
This renamed APK and the two-module button have **not** been live-flashed/root
tested in an emulator. No LD was rebooted or root environment changed while
building this release. The read-only Shell root diagnostic on LD-1 returned
Permission denied; that does not test manager-originated root operations.

These checks do not establish production security, Android lifecycle behavior,
game compatibility or correctness of the opaque ktools native binary.
