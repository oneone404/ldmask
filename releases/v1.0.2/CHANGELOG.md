# LDMask 1.0.2

- Remove the unofficial-build warning banner from the Home screen, including
  its Hide button and unused visibility preference/ViewModel code.
- Keep original Kitsune icon, LDMask identity and quick module installation.
- Modules toolbar: trash icon to delete only `/system/bin/su` and
  `/system/xbin/su`, with confirmation, independent-root preflight, temporary
  mount restoration and bounded execution. No directory deletion or reboot.
- App Install button refreshes update metadata at click time before displaying
  the update dialog, rather than relying on a stale in-memory release.
- Correct BusyBox fallback to the executable `.magisk/busybox/busybox` and
  reject directories. Failed actions do not exit the persistent root shell.
- No changes to root permission checks, environment validation or SU/Zygisk/
  MagiskHide algorithms. Removing a UI banner does not make this an official build.
- APK/native/script version/code: LDMask-1.0.2 / 27004.
- Both module ZIPs unchanged from v1.0.0/v1.0.1.

Experimental personal fork; release-mode binaries with the local Android debug
signing key. No automatic reboot or added service. Not an official or
security-audited Magisk/Kitsune distribution; upstream credits/licenses remain.
