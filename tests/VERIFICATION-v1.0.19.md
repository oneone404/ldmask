# LDMask 1.0.19 / LDLogin 1.27 — login-only and FramLogin dependency

Date: 2026-10-22, Asia/Bangkok. Validation performed before GitHub publication;
no production APK/module installation, real game operation, settings write or LD reboot.

## Behavior

- LDLogin alone matches only LOGIN and uses the unchanged account mapping/entry
  transaction. Each attempt is followed by a five-second wait; no 300-second limit.
  This branch precedes all game PID, launch, recovery and health logic.
- `open_backpack` remains the stored key for compatibility, now labelled FramLogin.
  It defaults OFF. Existing explicit ON/ON settings remain valid; installation does
  not overwrite user settings. Missing flags no longer imply automatic game launch.
- Turning LDLogin OFF in the native settings screen clears FramLogin in the draft
  and disables its control, including row clicks and busy-state refreshes. Turning
  LDLogin back ON does not restore FramLogin. Explicit Save is still required.
- Native settings reader/writer and runtime frame consumer independently suppress
  FramLogin if LDLogin is OFF. Old four-field UI descriptors remain accepted. Legacy
  three-field modules preserve their old implicit automation until module update.
- Only FramLogin enables the existing auto-start, recovery, health, popup and
  backpack/racket flow. Guard checks after captures and during waits prevent future
  actions after an observed OFF state; an already dispatched input cannot be undone.
- The explicit manual Mở Game button is unchanged. Root/Hide/LDMenu/LDNPH are not
  modified. This change does not introduce a logcat or network-disconnect listener.

## Validation

- 68 JVM tests, zero failures/errors/skips, including the actual three packaged
  module ZIPs, switch dependency, defaults, legacy descriptors, schema contracts
  and source-level placement of the login-only branch.
- `test-login-only-loop.ps1 -Serial emulator-5558`: all 12 mock main-loop cases
  passed, including indefinite absent-game scanning, real account-entry function
  with synthetic credentials, master OFF/ON, stale non-login results, full-mode
  resumption, and OFF during startup wait, health capture and image scan.
- `test-login-backpack.ps1`: all action/rapid-toggle cases passed with mocked game
  and input commands. The full-mode racket and fallback behavior remains covered.
- `test-login-backpack-native.ps1`: generated frames passed for all five full-mode
  templates; login-only excludes BALO/MENU/CONFIRM/OK and retains LOGIN. Actual
  inotify/FIFO and shell frame handling passed, including master re-enable and a
  deliberately inconsistent master-OFF/FramLogin-ON frame.
- `test-native-settings.ps1` with the final LDLogin ZIP passed: missing/invalid
  settings, round trips, symlink refusal, old-writer preservation, default OFF,
  orphan enable suppression and no automatic FramLogin resume.
- Android tests used unique scratch trees on emulator-5558, generated screenshots
  and mock actions only. Scratch data removed after each test. No production bot
  configuration, account file, real game or other LD was changed.
- Full four-ABI native + release APK build passed. Bundled root binaries carry
  LDMask-1.0.19 / 27021 consistently; root/hide source behavior is unchanged.
  APK signature verification passed using the existing
  certificate SHA256 `dc0754b98e885c80916f5da9eea6ea2aacc2f1f22e09040f4debafbd3c8a2621`.
  Existing Android Debug certificate and META-INF signature warnings remain.
- Native screen controls were build/source-contract/policy tested, not clicked in
  a live installed app. No claim of a long-running production test.

## Artifacts

Folder: `releases/v1.0.19`. Metadata targets GitHub release `v1.0.19`.

- LDMask.apk: io.github.oneone404.ldmask, LDMask-1.0.19 / 27021, 12,893,054 bytes;
  SHA256 `6acd540d066c6f814b300370c1a125f0a1a3967bb45645fcf44875a48840d510`.
- LDLogin.zip: v1.27 / 28, 159,846 bytes;
  SHA256 `9ffcd0995491d81e30e7a3e50d8835403e71d87be4118dcaf87f95a0661e4ce3`.
- Finder SHA256 `77dbbb6e47dacfc8ef9fdda0b1ddf5f4805fee11ee1cf3804b2dc53aa1604464`.
- LDMenu.zip and LDNPH.zip match v1.0.18 byte-for-byte. All module hash/size records
  match modules.json. Packaged module version and UI descriptor match source.

Install the APK before the module update. Reboot LD once to activate the updated
module script, not to re-root. Subsequent switch changes apply on explicit Save.
