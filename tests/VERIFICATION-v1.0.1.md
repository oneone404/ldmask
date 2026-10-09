# v1.0.1 verification — 2026-10-09

- Full release-mode app/native build passed.
- JVM tests: 14, zero skipped/failures/errors, including both real module ZIPs
  and the v1.0.1 release manifest.
- Packaged manifest references the original `drawable/ic_launcher`; original
  Kitsune icon resources are unchanged from the tested baseline commit.
- All 20 packaged native entries match Gradle's stripped-native output.
- Package/label retained: `io.github.oneone404.ldmask` / `LDMask`.
- APK/native version: LDMask-1.0.1 / 27003.
- APK v1/v2 signatures verified; existing local Android debug signing key.
- APK: 12,876,225 bytes; SHA-256
  `88452245a9ee097645d0d246704cadd95d3b3f89271f876f5ebeaf188fa02045`.
- Both module ZIPs are byte-identical to v1.0.0.

No APK/root/module installation or emulator reboot was performed for this
icon change. Device UI/root and dual-module live installation remain untested.
