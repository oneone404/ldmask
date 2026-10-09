# LDMask v1.0.4 verification — 2026-10-09

- Full native release rebuild and final release APK build succeeded.
- Package io.github.oneone404.ldmask, version LDMask-1.0.4 /27006,
  minSDK23/target34, original Kitsune icon unchanged.
- APK 12,864,103 bytes, SHA256
  `faa2eaaed08ce05fdfe9b53932cf8a5c277368a10e1ad43fad58c482cc8501f8`.
- Same Android debug signing certificate as previous LDMask patches; signature
  verified. Release-mode code, experimental signing, not production audited.
- MAGISK_DEBUG=0, native version LDMask-1.0.4 /27006. All 20 packaged native
  payloads match their Gradle stripped-native outputs.
- 26 JVM tests: 14 quick-installer including actual unchanged ZIP validation,
  12 source/UI contracts. No failures, errors, or skipped tests.
- Compiled layout inspection: one install ImageButton each in manager/Magisk,
  two icon actions per module, one quick-install Button without the hint,
  one standard icon-only FloatingActionButton on the flash screen.
- Removed install-method screen/classes/layout/navigation; direct-system root
  action is guarded by existing root and non-boot-patched environment, with
  Recovery=false at click and flash time. The upstream direct-system backend and
  its system/root behavior are NOT replaced or rewritten by these UI changes.
- Home checks update metadata on screen entry and click. Up-to-date/loading/
  unavailable states hide the manager icon; module icon requires a newer version
  and no pending removal/update. Icon descriptions retain accessibility semantics.
- No live APK installation, root/system install, module install/removal, reboot,
  or su cleanup performed for v1.0.4. No visual UI validation claimed: compiled
  XML and source contracts do not replace device click-flow testing.
- Both module ZIPs unchanged; latest release carries APK, two ZIPs, modules.json,
  update.json and CHANGELOG.md. No JSON/native module UI renderer added yet.
