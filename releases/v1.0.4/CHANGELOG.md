# LDMask 1.0.4

- Home manager card renamed LDMask.
- Magisk install is a single install icon, without a separate update icon/label.
- Magisk icon directly invokes the existing direct /system installer with
  Recovery disabled. Remove the install-method chooser screen/navigation/classes.
  Existing root and a non-boot-patched environment are required, as with the old
  system-install option. No boot image/recovery/emulator fix-env fallback.
- Manager install icon only appears when a newer APK version is known. No reinstall
  icon for current/newer versions or while checking/offline. Recheck metadata at
  Home entry and click time, not via background polling.
- Tools uninstall/restore actions are icons only. Module install icon only appears
  for an actual newer version, not mere update metadata or a pending update/removal.
- Flash completion reboot button is an icon-only FAB. No automatic reboot.
- Quick install label is “Cài Nhanh Module”; remove the download-hint paragraph.
- Icon-only controls retain accessibility descriptions and 48dp touch targets.
- No JSON native configuration renderer or WebUI added in this release.
- Both module ZIPs unchanged. Root installation was not performed on a live LD
  during validation; first-run install/click behavior still requires user testing.

Experimental Kitsune-based fork, not official Magisk. Original credits/licenses
remain. Release-mode APK uses the same local Android debug signing certificate.
