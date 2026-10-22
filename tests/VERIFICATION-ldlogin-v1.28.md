# LDLogin 1.28 — confirmation popups in login-only mode

Date: 2026-10-23, Asia/Bangkok.

## Change

- Login-only native batch matching now searches LOGIN, CONFIRM and OK in one
  screenshot using their existing ROI/confidence thresholds. BALO and MENU remain
  excluded. No extra screenshot or resident process was added.
- The shell login-flow result handler validates the tag, score format, coordinates
  and master gate before tapping. CONFIRM/OK wait briefly and return before account
  selection or entry. Only LOGIN reaches the unchanged account transaction.
- Login-only main-loop placement, five-second wait, indefinite duration, FramLogin
  dependency/defaults and all launch/recovery/health exclusions remain unchanged.
- LDLogin version v1.28 / 29. APK LDMask 1.0.19 / 27021 and root payload are unchanged.

## Verification

- 69 JVM tests passed with no failures/errors/skips, including the new result-handler
  source contract and validation of the actual packaged module ZIPs.
- Real native finder on generated 960x540 frames: full mode still matches all five
  templates; login-only matches LOGIN/CONFIRM/OK and rejects BALO/MENU.
- All native inotify/FIFO, master/FramLogin dependency and settings round-trip tests
  passed with the updated binary/ZIP.
- Production action functions with mocked input/finder: CONFIRM/OK click without
  account entry; unsupported/malformed result and master-OFF cases perform no input;
  full-mode racket/fallback and rapid-switch regression tests still pass.
- Production main-loop fixture: 13 cases passed, including repeated popup handling
  without account access, CONFIRM -> OK -> LOGIN consuming exactly one synthetic
  account, no launch/health work in login-only mode, and mode-change guards.
- Android tests used emulator-5556 with unique scratch trees, generated screenshots
  and mock actions. Scratch trees removed. No production APK/module installation,
  bot settings/account file write, game click/launch/stop, network change or reboot.
- Production shell syntax and git diff whitespace checks passed. No live UI or
  long-running production session is claimed.

## Package

Folder `releases/ldlogin-v1.28`, prepared with nine release assets.

- LDLogin.zip: 159,942 bytes, SHA256
  `3ac79ed03f28a84835f4edf769e3df9d43ad431d9dd91e6dfc3ea80feab0276d`.
- Native finder: 207,792 bytes, SHA256
  `cd65b843898f24148ad1b602b491bd7d6bd5d4b49746a9485ac101283f30a58c`.
- LDMask.apk, LDMenu.zip and LDNPH.zip match published v1.0.19 byte-for-byte.
  Manifest sizes and hashes match all three packaged modules. APK update metadata
  remains version 27021, so existing LDMask 1.0.19 clients are not offered a new APK.

Update only LDLogin, then explicitly reboot LD once to activate the new script.
No re-root or APK update is required for existing LDMask 1.0.19 installations.
