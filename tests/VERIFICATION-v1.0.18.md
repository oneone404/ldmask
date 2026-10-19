# LDMask 1.0.18 — LDNPH selection crash hotfix

Date: 2026-10-20, Asia/Bangkok.

## Observed failure

- Index 0 / LDPlayer, LDMask APK and core 1.0.17 / 27019.
- Android crash buffer contained main-thread `IllegalArgumentException: Failed requirement` at 00:23:54 and 00:25:24, in the ChooseModulesDialog callback with ModuleViewModel.confirmQuickInstall inlined.
- Both UI confirmation and FlashViewModel still had a two-ID allowlist. NPH was visible from the new catalog but rejected by these gates. At inspection, its active and staged module folders were absent. This is an app routing failure before installation, not evidence of a native NPH or VM crash.
- Windows had no matching recent LD crash event; VM remained present. No diagnostic action restarted the LD or modified modules/settings.

## Fix

- QuickModuleCatalog owns selection validation, canonical encoding and strict decoding for all three known IDs.
- Picker uses encodeSelection and returns false on invalid/empty selection instead of throwing. Dialog dismisses only after an accepted navigation.
- Flash screen decodes through the same catalog under runCatching, reports invalid selection without installing, and passes valid NPH-only/mixed selections through.
- Installer selection and cleanup use the shared validator. Publication/availability is still rechecked before installation; unknown IDs, invalid hashes, ZIP paths and hidden selections remain rejected.
- NPH remains explicit opt-in. Default/null selection still excludes it.

## Validation

- 64 JVM tests, zero failures/errors/skips. New regression tests encode/decode each of 7 non-empty selections and run the actual QuickModuleInstall transaction with synthetic ZIPs and a mocked installer callback, verifying only selected modules reach installation, cache cleanup, and preservation of all published modules.
- Malformed/empty/unknown/duplicate/oversized payloads return null. Source contracts pin picker and flash screen to the shared validator and reject reintroduction of the duplicated two-ID gates.
- Actual release ZIP validation passed for all three unchanged module assets. These tests are not a live UI click or root installation test.
- Full four-ABI release build passed. APK package io.github.oneone404.ldmask, LDMask-1.0.18 / 27020.
- APK size 12,893,054 bytes; SHA256 `b7dad9296c6215a22b508bf3b9b3c482094186f8b9e216d7202d337ad2bdc145`.
- apksigner verification passed with unchanged certificate SHA256 `dc0754b98e885c80916f5da9eea6ea2aacc2f1f22e09040f4debafbd3c8a2621`. Existing Android Debug certificate and META-INF warnings remain unchanged.
- LDLogin 1.25 / 26, LDMenu 1.2 / 3 and supplied LDNPH / 1 ZIPs copied byte-for-byte from v1.0.17. No module payload or root/hide behavior fix is claimed here; core build changes release version metadata only.
- No APK installation, module installation, root setting change, game operation or LD reboot performed during this hotfix. APK update alone applies the routing fix; it does not require root reinstallation or reboot.
