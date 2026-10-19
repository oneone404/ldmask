# LDMask 1.0.17 / LDLogin 1.25

Date: 2026-10-20, Asia/Bangkok.

## Feature behavior

- Native JSON UI adds boolean `open_backpack`, label `Mở Balo`, default true for valid older configuration. Missing/invalid settings still leave the master bot disabled.
- With this switch off, batch matching skips BALO and MENU before template decoding. LOGIN, CONFIRM and OK are unchanged, as are the existing 300-second image-flow window and game health checks.
- Shell action guards recheck the switch after capture and before input. The backpack click now separates fresh matching from input so OFF events during capture can be observed before tapping. Failed input does not enter the racket flow.
- Panel delay, racket retries and fixed-coordinate fallback all honor the switch. Observed OFF/ON sequences invalidate an in-flight backpack operation; this cannot undo an input already dispatched to Android.
- Same inotify watcher/FIFO; no new background process or JSON polling. STATE2 frames carry the new flag, fail closed on malformed/mismatched frames, and publish backpack-only changes. Re-enabling from monitoring starts image handling without force-stopping the game solely for a setting change.
- New app accepts old three-field descriptors and new four-field descriptors. Legacy native --settings output is preserved; --settings-v2 includes the fourth value. Old three-argument writers preserve a stored backpack flag. Updating only the module is not sufficient for old managers to render the new descriptor: update APK first, then LDLogin and explicitly reboot once for activation.

## Catalog

- LDNPH is the exact supplied ZIP, original ID `zygisk_il2cppdumper`, v1.2.0 / code 1. Not installed or executed during testing. Binary behavior has not been audited; metadata attribution is not provenance authentication. See module-src/ldnph/README.md. It is opt-in even for null-selection callers; default selection remains LDLogin/LDMenu.
- Catalog `optionalModules` holds LDNPH; existing `modules` holds LDLogin/LDMenu so older clients can still parse the two base rows. Publication and manifest validation reject duplicates across groups and keep original ID/hash/path/size validation.
- New-client cleanup preserves all published modules, not only selected modules, including LDNPH; unpublished modules follow existing removal-marker rules. Old apps do not know LDNPH and may mark it for removal when running their cleanup. Update app before using it.

## Validation

- Full four-ABI core/app release build succeeded; existing toolchain/compiler warnings remain. No native root/hide behavior changes from upstream were integrated; only release version metadata changes in the core.
- 61 JVM tests passed, zero failures/errors/skips, including all three actual release ZIPs (forced task rerun with LDMASK_RELEASE_FILES pointing to releases/v1.0.17).
- Native settings fixture passed on LD-1 / emulator-5556: defaults, legacy config, old writer preservation, explicit OFF/ON, invalid types/range and symlink refusal.
- Real finder on generated 960x540 frames passed all five default matches; login-only excluded BALO/MENU and retained LOGIN/CONFIRM/OK. Initial failed frames were traced to GDI image-copy transformations in the fixture; pixel-exact copying fixed the test data, without production matcher changes.
- Real native watcher plus production shell gate passed initial STATE2, backpack-only OFF/ON with master enabled, master OFF, and malformed configuration fail-closed.
- Production shell functions with mocked game/input/clock passed stale BALO/MENU rejection, LOGIN/CONFIRM/OK preservation, racket success/fallback, OFF during pre-backpack wait/panel delay/retry, and observed rapid-toggle cancellation.
- Module migration/cleanup fixture passed all cases including preserving a published LDNPH in active/staged trees and retiring it when unpublished.
- Android tests used generated temporary files and helpers only: no production module install, settings writes, game input, game launch, key access, root changes or LD reboot. LD-1 was already opening when selected; no launch command was issued by this change.
- No end-to-end test inside the real game or live config UI; no multi-hour benchmark. Fixtures are not proof of universal game compatibility or root invisibility.

## Artifacts

- LDMask.apk: package io.github.oneone404.ldmask, LDMask-1.0.17 / 27019, 12,893,054 bytes. Final rebuild SHA256 `b9dabb9d43f8da34b80d36fe85dcf0d868e385d1fc8056d3655d944c1136f2b7`.
- apksigner verification passed with unchanged certificate SHA256 `dc0754b98e885c80916f5da9eea6ea2aacc2f1f22e09040f4debafbd3c8a2621`. Existing Android Debug certificate and META-INF verification warnings remain; no signing migration performed.
- LDLogin.zip: v1.25 / 26, 159,459 bytes. SHA256 `a4091933faae06444ed15932bd6ec87407fc40ca144a6ead2bc3f8e869ff5a71`.
- Finder: 207,808 bytes. SHA256 `c5cfdfeb6d0e61f1babd5e9e385d39ee79fb2fbc36c467b91953eda31d7f58ee`.
- LDMenu.zip: copied byte-for-byte from v1.0.16, v1.2 / 3, SHA256 `aa660113a218ee206e16346c78cd9853222efcb63dbde6f13e4e6f9257311cdf`.
- LDNPH.zip: exact supplied archive, 502,389 bytes, SHA256 `7958565e9d3fc17b0fcf39f9899a4e6b298b51ed3c1c63858cbbbe0c09d376a1`.

Upstream review: UPSTREAM-REVIEW-20261020.md. No verified LD-specific upstream fix selected for this build.
