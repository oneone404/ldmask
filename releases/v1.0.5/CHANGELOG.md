# LDMask 1.0.5

- Home: bold details without Installed/Latest/Package labels. The LDMask card
  shows the remote-version row and install icon only for a newer APK.
- Magisk: installed version, Zygisk and Ramdisk with check/X icons.
- Rename Settings to Configuration (Cấu Hình); remove all three descriptions.
- After successful direct-system root install only, preset Zygisk=1, MagiskHide=1
  and SuList=0 (Hide mode, never adding games to the allowlist).
- Hide com.vng.playtogether and com.haegin.playtogether only if installed,
  including manifest-declared secondary processes. Preserve other Hide entries.
- Root failure never triggers the preset; configuration failure reports that root
  may already have been installed. No Launcher/LDMask target.
- Root-owned atomic one-shot post-fs-data hook applies before this fork reads
  Zygisk/Hide flags on the next boot. Verify data before self-removal; keep the
  hook on failure. Bounded existing-daemon write attempt, no forced restart.
- Explicit reboot required for activation. No auto reboot, new service or polling.
- Includes v1.0.4 icon-only actions, Cài Nhanh Module and direct /system install
  without a method chooser, with Recovery disabled. Existing root is required.
- Both module ZIPs unchanged; no JSON/native module settings renderer yet.

Experimental Kitsune-based fork, not official Magisk. Credits/licenses retained.
Same local Android debug signing certificate. Build/JVM/SQLite/mock shell checks
passed; no live root reinstall or reboot performed during this validation.
