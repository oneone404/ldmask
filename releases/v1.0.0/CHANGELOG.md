# LDMask 1.0.0

- App label: LDMask; package: `io.github.oneone404.ldmask`.
- Native default root-manager package matches LDMask. Reinstall root for this
  identity; installing only the APK does not migrate the old root daemon.
- Modules tab: **Quick install OneOne + ktools**, from the latest stable release.
- Verify both ZIPs (size, SHA-256, module ID, versionCode and ZIP paths) before
  installing either. Install sequentially, report partial failure, clean private
  download files on normal success/failure. No automatic reboot.
- Existing manual ZIP install remains available. No extra service or polling;
  periodic app-update checking is disabled by default.
- App update metadata now points to this fork rather than upstream Kitsune.

This is a personal, experimental fork of a community Kitsune snapshot, not an
official Magisk/Kitsune release. Root/SU/Zygisk/MagiskHide algorithms are unchanged.
The APK uses release-mode native code and the local Android debug signing key;
it is not a security-audited production distribution.

OneOne: v1.22 (23), `oneone`. ktools: v1 (1), `ktools_zygisk`.
The ktools binary/source/license has not been independently audited.
