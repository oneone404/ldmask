# LDMask v1.0.9 verification — 2026-10-09

- Full native/release app build successful; final app rebuilt after label edits.
- Package `io.github.oneone404.ldmask`, version `LDMask-1.0.9` / `27011`.
- APK 12,880,655 bytes, SHA-256
  `a90437346da330791ea5f2d5756272817e0143fce99b3c1534234e2161082bec`.
- apksigner verification passed; same experimental Android debug certificate as
  prior releases. Existing META-INF signing warnings remain unchanged.
- JVM suite: 51 tests, zero failures/skips, with actual release ZIP validation.
- Source contracts check no picker/load/save informational notes, error handling
  retained, and Vietnamese action labels Xoá All Module / Xoá Su Bin/Xbin.
- LDLogin/LDMenu ZIPs are byte-identical to v1.0.8; no bot or module logic changes.
- No APK/module flash, root/config changes, reboot or destructive action was
  performed against running LDs. This verification does not measure live app RAM
  or claim new emulator performance improvements.
