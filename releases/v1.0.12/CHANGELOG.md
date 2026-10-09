# LDMask 1.0.12

- Hide the empty-module message in Tools.
- Verify both Su Bin/Xbin files are absent and independent Magisk root works after cleanup.
- Verified deletion reports success even if read-only remount restoration failed; keep mount warnings and pending recovery state in the log.
- Remaining files, dangling Su symlinks or failed verification still report failure.
- MagiskHide/Zygisk presets, game-launch behavior and LDLogin/LDMenu ZIPs unchanged.
