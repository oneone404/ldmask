# v1.0.2 verification — 2026-10-09

- Full release native/app build and final release app rebuild: passed.
- JVM suites: 18 tests total, zero skipped/failures/errors (14 pair-install
  tests including real ZIPs, four source-level UI/cleanup contracts).
- Compiled Home layout parses; old banner view IDs are absent. Unused translated
  strings may remain in resources; they are not Home views.
- Compiled Modules menu contains the trash action with showAsAction=always.
- Original Kitsune icon and LDMask package retained.
- Native version/code: LDMask-1.0.2 / 27004; all 20 packaged native entries
  verified against Gradle's stripped-native outputs during this build.
- APK v1/v2 signatures verified. Certificate SHA-256 matches prior LDMask builds:
  dc0754b98e885c80916f5da9eea6ea2aacc2f1f22e09040f4debafbd3c8a2621.
- Final APK 12,905,008 bytes; SHA-256
  `4a9b972957d34af7fe8c17cbc7f042d0b8acdacef46742353b44b0509f7c280b`.
- Module ZIPs unchanged; release manifest validated in JVM tests.

No live system-su deletion, remount, root install, reboot, APK installation or
Android in-place update was performed. ADB had no connected devices at inspection.
Cleanup tests are source contracts, not execution of the shell script. Root
preflight/mount restoration and manager update require live LD verification.
Source provenance and experimental-build disclosures remain in docs/releases.
