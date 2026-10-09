# LDMask v1.0.10 verification — 2026-10-09

- Full native/release APK build successful, package `io.github.oneone404.ldmask`,
  version `LDMask-1.0.10` / `27012`.
- APK 12,884,807 bytes; SHA-256
  `e3ae02a83e450db88baa1b40fcdb3d8a6c9dfba9e8d3332e6c8df19aaa6be7cd`.
- apksigner verification passed with the unchanged experimental Android debug
  certificate. Existing META-INF signing warnings remain.
- JVM suite: 52 tests, zero failures/skips, including actual release ZIP hashes.
- Non-root Android mock launch fixture: nine cases passed (normal/already running,
  no root, missing/foreign/malformed component, nonzero start, zero-exit error,
  exception output). All `id`, `cmd`, `am` operations were intercepted; no real
  game launch/stop was performed. The generated fixture directory was cleaned.
- Read-only resolution on LDPlayer-2 confirms its VNG launcher activity is
  `com.vng.playtogether/com.google.firebase.MessagingUnityPlayerActivity`.
- Source contracts verify Mở Game follows Tải Lại, UI busy guard, IO/root backend,
  15-second timeout, one start request, no stop/restart or implicit config save,
  and no informational success note. No new service/polling/network request.
- Module ZIPs unchanged from v1.0.9. No root reinstall, APK/module installation,
  reboot, settings mutation or real game launch was performed on running LDs.
  User click integration and actual foreground launch still require a live test.
