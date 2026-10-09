# LDMask v1.0.5 verification — 2026-10-09

- Full native release rebuild and final app release build succeeded.
- APK io.github.oneone404.ldmask, LDMask-1.0.5 /27007, minSDK23/target34.
- APK 12,864,103 bytes; SHA256
  `a45ade6c27932ca831779bc7ec3726a305d28abe82501cdcab1e3c51022f332a`.
- Signature verified; same experimental Android debug signing certificate:
  `dc0754b98e885c80916f5da9eea6ea2aacc2f1f22e09040f4debafbd3c8a2621`.
- Native LDMask-1.0.5 /27007, MAGISK_DEBUG=0. All 20 packaged native payloads
  match stripped Gradle outputs. Original Kitsune icon retained.
- 33 JVM tests passed: 14 quick-installer, 15 source/UI contracts, 4 preset planner
  tests. No failures/errors/skips; actual unchanged module ZIP pair validated.
- Actual Kotlin planner invoked by Java reflection, generated SQL tested with
  SQLite in RAM: flags, both games, secondary process, idempotence, retain other
  settings/Hide entries, verification rejects a missing target.
- Generated hook passed Android sh -n. Five non-root stdin fixtures mock all
  id/magisk/rm calls: immediate success retains hook; boot success removes it;
  verification failure, SQL-write failure and non-root do not remove it.
- Initial test runner needed correction for Kotlin runtime lookup/PowerShell
  quoting and reconnection to existing LDPlayer-2. Final checks passed. No LD launch.
- Compiled Home layouts: one install ImageButton each, two Magisk status ImageViews,
  three manager detail TextViews. Bold/visibility checked through source contracts.
  This is not visual Android UI validation.
- Preset gated by successful direct-system install. Fixed packages, validated
  process names, root-owned atomic hook. Immediate persistence bounded at 10+2s.
- native/src/core/bootstages.cpp runs common post-fs-data scripts before reading
  Zygisk config/initializing Hide. Hook verifies persistence, self-removes only on
  successful boot application. User reboot required; no daemon/zygote forced start.
- Safe-mode boot skips hook; failure retains it. Other root policies are not reset,
  except explicitly Zygisk=1, MagiskHide=1, SuList=0 as the root-install preset.
- No live APK install, root/system install, module install/removal, su cleanup,
  reboot or actual Hide mutation. First-root integration still needs user testing.
- Both module ZIPs unchanged; six release assets. No native JSON settings UI yet.
