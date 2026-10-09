# LDMask v1.0.11 verification — 2026-10-09

- Full native/release build successful. Package `io.github.oneone404.ldmask`,
  version `LDMask-1.0.11` / `27013`.
- APK 12,884,807 bytes; SHA-256
  `acf3970131c25091cd602b7de404407ff9d33fda4d8a78718e7b840f3a08ef67`.
- apksigner verification passed with the unchanged experimental Android debug
  certificate. Existing META-INF signing warnings remain; this is not a security audit.
- JVM suite: 52 tests, zero failures/skips, including real release module ZIP hashes.
- Non-root Android mock launch fixture: 18 cases passed on `emulator-5554`.
  Root, package resolution, PID, Activity, launch, stop and clock operations were
  intercepted. No real game was opened/stopped, no root configuration was changed,
  and the generated fixture directory was cleaned.
- Fixture cases cover ready/background games, stuck startup, retry recovery,
  a running-process race before force-stop, lost focus, subsequent disappearance,
  persistent attach failure, failed/unknown dumpsys, force-stop error, no root,
  missing/foreign/malformed component and start errors including zero-exit errors.
- A healthy game observed during the click remains protected from force-stop.
  Readiness requires two attached foreground Activity observations with the same PID.
  At most three start requests; individual commands and the overall worker are bounded.
  Unknown state is not force-stopped. UI launch success/failure is intentionally silent.
- No new service, background monitor, module ZIP change or settings mutation.
  Shared Pictures APK copy hash matches the verified build. No APK/module installation
  or LD reboot was performed.
- Live validation on LDPlayer-2 is pending: it is no longer in `ldconsole list2`;
  its former ADB endpoint `127.0.0.1:5559` is unavailable. Only LDPlayer/index 0
  is currently running. The mocked test on that device is not a live game test.
- Earlier LDPlayer-2 diagnosis showed `failed to attach` / `start timeout` after root.
  An `am start` exit of zero and a stale resumed Activity did not imply a live game PID.
  The new workflow handles bounded recovery, but the underlying post-root attach
  problem has not been isolated or proven fixed. No Hide/Zygisk/module settings
  were changed in this request; controlled one-factor testing is the proposed next step.
