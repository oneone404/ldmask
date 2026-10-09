# LDMask v1.0.8 verification — 2026-10-09

- Release app build successful, package `io.github.oneone404.ldmask`,
  version `LDMask-1.0.8` / `27010`.
- APK: 12,892,943 bytes, SHA-256
  `e0b2e4fdcdb468e61f94585b2d116737becae6f599c056984a68955d720469ed`.
- apksigner verification succeeded; certificate SHA-256 unchanged:
  `dc0754b98e885c80916f5da9eea6ea2aacc2f1f22e09040f4debafbd3c8a2621`.
  The existing experimental Android debug signer and META-INF signing warnings
  remain; this is not a security-audited production root manager.
- JVM suite: **50 tests, zero failures, zero skips**, including both actual
  release ZIPs via `LDMASK_RELEASE_FILES`.
- Android non-root migration/cleanup fixtures: **22 assertions passed**.
  Real script paths were rewritten into a unique `/data/local/tmp` directory;
  UID/install helpers were mocked. Settings migration/no overwrite, inherited
  disabled state/reinstall, full published-list retention, unknown active/staged
  retirement, unpublished modules, symlinks and empty allowlist were covered.
- Native settings fixture: **5 cases passed** using the newly built LDLogin
  finder: missing defaults, save/read round-trip, invalid range preservation,
  symlink refusal, malformed fail-closed config.
- LDLogin: `ldlogin`, version 1.24 /25; ZIP SHA-256
  `8c72c673bc1820488db014ad500ac1ed791dc74d0c92cbb1807c4a571377b70c`.
- LDMenu: `ldmenu`, version 1.1 /2; ZIP SHA-256
  `daae057df8140222fc702180d9758e8793fcec0eae07ca61f1e95defee728bf5`.
- LDLogin native changes are mechanical identity/path renames of the prior
  source; VNG remains the only bot target. LDMenu's two ABI payloads are
  byte-identical to the verified v1.0.7 user-supplied ktools binary payloads.
- Cleanup is only after successful selected installation and keeps the full
  server-published list, not just checked modules. Magisk remove/disable flags
  finish removal on explicit reboot; external data/root is not recursively wiped.

No APK/root/module installation, bot setting change, real module cleanup or
reboot was performed on running LDs for these tests. Native UI click integration,
boot migration/activation and LDMenu compatibility after its ID change still
require a real user installation and reboot test before cloning LDs.
