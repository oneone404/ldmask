# LDMask 1.0.8

- Rename module IDs to ldlogin/ldmenu and assets to LDLogin.zip/LDMenu.zip.
- Migrate old bot settings to /data/adb/ldlogin/settings.json; retire legacy modules at reboot. Keep any existing new settings instead of overwriting them.
- Publish LDLogin source/native build in module-src/ldlogin; LDMenu native payloads remain unchanged opaque user-supplied binaries.
- Label the separate native bot switch LDLogin, without the Bật prefix.
- Remove the missing/invalid configuration notice from normal UI; fail-closed bot defaults remain unchanged.
- Keep VNG com.vng.playtogether as the only bot target. No Haegin picker or package-switching code.
- The bot switch takes effect after Save without reboot while its module service is running.
- Magisk's separate module enable switch retains its normal reboot semantics.
- After successful selected installation, retire modules outside the complete server-published list, including active/staged modules. Merely opening/cancelling the picker removes nothing; failures before completion trigger no general cleanup.
- Removal uses Magisk flags and requires reboot to finish; it does not recursively delete root or unrelated external data.
- LDLogin v1.24 /25, LDMenu v1.1 /2. Update LDMask first, then install both renamed modules and reboot once for migration.
