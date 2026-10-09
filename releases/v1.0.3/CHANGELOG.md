# LDMask 1.0.3

- Default light Fraxure (Legacy) theme, including existing LDMask installations.
- Home / Superuser / Log / Tools navigation. Remove support and follow cards.
- Settings only expose Magisk: Zygisk, MagiskHide and Configure MagiskHide.
  Other root policy/preferences are preserved, not reset during an update.
- Compact module cards; remove the install-from-storage button.
- Tools toolbar trash popup offers all-module removal or exact system-su cleanup.
- All-module removal marks active AND staged modules for removal on next reboot.
  Explicit confirmation, no automatic reboot, no root removal, no recursive UI deletion.
- System-su cleanup persists a pending RO restoration obligation, verifies mount
  state and reports partial deletion separately. An already-absent file does not
  hide a writable system mount. Kernel remount refusal still requires user recovery
  (usually reboot); this update does not guarantee every remount will succeed.
- Module ZIPs unchanged. No WebUI or additional background service added.

Experimental Kitsune-based fork, not official Magisk. Original credits/licenses
remain. APK uses release-mode code signed with the same local Android debug key.
APK updates do not automatically reinstall the native root environment.
