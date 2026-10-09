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
LDMask uses package `io.github.oneone404.ldmask`, separate from the tested baseline
`io.github.huskydg.magisk`. The native default manager package changes with it:
reinstall the root environment, not just the manager APK. Existing root paths,
Magisk module format and original credits are retained.

The v1.0.0 APK uses release-mode app/native code but the local Android debug
signing key. This is an experimental build, not a security-audited production
distribution. Signing material is not included in this repository.

## Build

See docs/build.md. Use Python 3.8+, JDK 17, SDK/build tools 34, Gradle 8.6 and
ONDK r26.3. On Windows enable symlink support as required by that guide, or
materialize the ONDK symlink aliases locally. Keep signing keys private.

Baseline: `python build.py -v all` (optional local config.prop, ignored by Git).
Fork: `python build.py -v -r -c config.ldmask.prop all`.

Run JVM tests with `gradlew :app:testDebugUnitTest -PconfigPath=config.ldmask.prop`.

## Quick module installation

The Modules tab downloads `modules.json`, `OneOne.zip` and `Module.zip` from
`https://api.github.com/repos/oneone404/ldmask/releases/latest`. Only published,
stable releases with the complete pair and matching fixed IDs are accepted.
Both ZIPs are checked before either root command runs. Temporary files are
private to the app cache and removed in `finally`; app/process termination can
leave a temporary directory behind. Root installs are serialized with the
existing manual ZIP installer and use a 180-second BusyBox timeout per module.
If module 2 fails, module 1 is reported as installed; no destructive rollback.
Reboot is always explicit. An installer timeout does not guarantee that a
module's independently spawned background process has stopped.

To publish another pair, upload all release assets as a draft, supply the exact
release tag/sizes/SHA-256/versionCodes in `modules.json`, then publish the draft.
Never replace a published ZIP without updating its manifest. The APK needs no
embedded GitHub token. Do not publish account files or private settings.

Periodic manager-update checking is disabled by default; opening the UI and
pressing quick-install can still use the network. Non-custom manager update
channels point to this fork's `update.json`, not upstream packages.

No new background service or polling is required for the quick-install feature.
