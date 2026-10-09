# LDMask v1.0.6 verification — 2026-10-09

- Full native release rebuild and final R8 release app build passed.
- Package io.github.oneone404.ldmask, LDMask-1.0.6 /27008, minSDK23/target34.
- Final APK 12,876,448 bytes, SHA256
  `675338b547ad5296bafa9778b31bcb10bbf199d305449ed011759ca6ef5126fb`.
- Signature verified, unchanged experimental Android debug certificate
  `dc0754b98e885c80916f5da9eea6ea2aacc2f1f22e09040f4debafbd3c8a2621`.
- Native version 1.0.6 /27008, MAGISK_DEBUG=0; all 20 APK payloads match stripped
  native outputs. Original Kitsune app icon unchanged.
- 41 JVM tests passed (4 root preset, 16 UI/source contracts, 4 native-schema,
  17 quick-installer); no failure/error/skip. Actual v1.0.6 ZIP pair validated.
- Quick tests cover selected-only installation, malformed publication, no/foreign
  selection, full selected prevalidation, partial root-install failure and cleanup.
- Native schema tests use the actual module descriptor and reject unsupported
  module/commands/paths/duplicate keys/unsafe defaults/float or invalid ranges.
- Non-root LDPlayer-2 fixture ran the actual unchanged finder: missing settings
  OFF/30/no-log, valid round-trip, invalid range preserves file, symlink write
  refused, malformed file fails closed. Exact temporary test directory cleaned.
  It never touched /data/adb/oneone/settings.json or any real bot/account data.
- OneOne ZIP 154,605 bytes, SHA256
  `4fc7f1f4d07c9f992dcf12bd83a0f8f07117ee65d4fb54ae4dd012ddfa48b755`.
  All base ZIP entry contents unchanged except module.prop version v1.23 /24;
  exactly one new entry ui.json. Existing scripts/binary/image hashes compared.
- ktools ZIP unchanged. Packaging helper first required explicit ZipFile assembly
  loading under Windows PowerShell; failed base-copy artifact removed only after
  checking exact known base hash, then rebuilt/validated successfully.
- Root settings repository reads on UI open/reload/save, timeout10+2s, fixed paths,
  symlink/type guards, bounded schema/data, native atomic writer and readback.
  Fingerprint conflict check is optimistic, not a cross-app mutex/CAS guarantee.
- New registered native configuration backend supports OneOne only. No arbitrary
  root schema command/path, WebView, JS, foreground service or polling added.
- Public catalog visibility is not access control. Older APKs/public asset links
  are not restricted. Hidden module rechecked before quick install.
- No live APK installation, module/root installation/removal, bot enable/disable,
  su cleanup or reboot. No visual UI/full root-repository integration claim; user
  should test the gear/picker flow after installing this APK and OneOne v1.23.
- Existing dirty modulelogin repository/local module source was not overwritten.
