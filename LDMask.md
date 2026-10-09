# LDMask

Personal Kitsune Mask fork for LDPlayer, published at
https://github.com/oneone404/ldmask.

The baseline was successfully rooted on LD-1 by the user before adding the
quick-module installer. Root/SU/Zygisk/MagiskHide algorithms are not changed by
that UI feature. This is not an official HuskyDG or topjohnwu release.

## Source provenance and license

Based on community snapshot https://github.com/zcg9783/KitsuneMagisk1 at
ce81d9916d5a808567f4b31481ac840e4c21fc82 (`20240705-drop`). Exact identity to
HuskyDG's R6687BB53 build is not verified. Preserve LICENSE and original credits.
Magisk/Kitsune source is GPL-3.0-or-later, including its component licenses.

Baseline build repairs: vendored cxx version alignment in Cargo.lock; Windows
BusyBox forced-include path correction; missing generated BusyBox headers from
topjohnwu/ndk-busybox commit 1c0ca97aafb9698ab7770ce1f67af1a84b469cdb (2024-06-18).

## Release files

- `LDMask.apk`: locally built manager/root APK.
- `OneOne.zip`: user-owned OneOne module.
- `Module.zip`: user-supplied compiled ktools module, ID `ktools_zygisk`.
  Its native source is not provided by this repository; do not imply it is GPL
  source or audited merely because it is distributed beside this fork.
- `modules.json`: release-specific module IDs, sizes, versions and SHA-256.

Signing keys, accounts, emulator data and private configuration are not published.
Development APKs use the same local Android debug signing key as the tested
baseline. These are test builds, not security-hardened production releases.

## Build

See docs/build.md. Use Python 3.8+, JDK 17, SDK/build tools 34, Gradle 8.6 and
ONDK r26.3. On Windows enable symlink support as required by that guide, or
materialize the ONDK symlink aliases locally. Keep signing keys private.

Baseline: `python build.py -v all` (optional local config.prop, ignored by Git).
Fork: `python build.py -v -c config.ldmask.prop all`.

No new background service or polling is required for the quick-install feature.
