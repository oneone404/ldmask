# LDMask

Personal Kitsune Mask fork for LDPlayer, published at
https://github.com/oneone404/ldmask.

The baseline was successfully rooted on LD-1 by the user before adding the
quick-module installer. Root/SU/Zygisk/MagiskHide algorithms are not changed by
that UI feature. This is not an official HuskyDG or topjohnwu release.

Since v1.0.13, native MagiskHide namespace creation is repaired: the old single
pipe let the worker consume its own readiness message and exit while the daemon
waited forever. This was captured on LD1 during a VNG startup timeout. A detached
worker now transfers the open namespace FD through an atomic socketpair packet;
the FD survives worker exit, the receive has a 3-second deadline, and namespace
cache initialization/reset is serialized. No additional resident service/polling
and no disabling Hide to make the game launch. Failed creation/setns is reported
as failure rather than falsely returning success. Root hiding is not guaranteed
undetectable: LDMenu and its loader can still appear in game/companion maps.

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
- `LDLogin.zip`: user-owned module, ID `ldlogin`; source in `module-src/ldlogin`.
- `LDMenu.zip`: user-supplied compiled ktools payload, module ID `ldmenu`.
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

The Tools tab downloads release `modules.json` and selected ZIPs from
`https://api.github.com/repos/oneone404/ldmask/releases/latest`. Only published,
stable releases with integrity metadata and matching fixed IDs are accepted.
Server `catalog.json` controls publication and the native picker selects one or both.
All selected ZIPs are checked before any root command runs. Temporary files are
private to the app cache and removed in `finally`; app/process termination can
leave a temporary directory behind. Root installs are serialized with the
existing manual ZIP installer and use a 180-second BusyBox timeout per module.
If module 2 fails, module 1 is reported as installed; no destructive rollback.
Only after all selected installs succeed, modules outside the complete current
server-published list are disabled/marked for removal in active and pending roots.
An allowed module is retained even when unchecked. Opening/cancelling the picker
or a failed download/validation/installation triggers no general cleanup.
Uninstall finishes at the next Magisk boot, including normal uninstall scripts;
arbitrary external module data is not recursively erased. Cleanup failure is
reported separately from successful module installations. No empty allowlist wipe.
Reboot is always explicit. An installer timeout does not guarantee that a
module's independently spawned background process has stopped.

To publish another pair, upload all release assets as a draft, supply the exact
release tag/sizes/SHA-256/versionCodes in `modules.json`, then publish the draft.
Never replace a published ZIP without updating its manifest. The APK needs no
embedded GitHub token. Do not publish account files or private settings.

Periodic manager-update checking is disabled by default; opening the UI and
pressing quick-install can still use the network. Non-custom manager update
channels point to this fork's `update.json`, not upstream packages.

## System su cleanup (v1.0.2)

The Modules toolbar trash icon opens a confirmation naming exactly
`/system/bin/su` and `/system/xbin/su`. It does not delete directories, follow
target symlinks, erase `/data/adb`, remove modules, or reboot. It first verifies
an independent working Magisk `su`/`magisk` path; if root depends on a target
file it refuses. Missing targets are accepted. The independent root path must
also be in the app's original PATH, to avoid losing bare `su` discovery when
the manager is restarted. Read-only mounts may be remounted temporarily, with
restoration in a trap and failures reported. Partial deletion
is possible if the second target fails; there is no backup or automatic rollback.
Execution uses the existing root shell and a 30-second BusyBox timeout, sharing
the module-install gate. Process kill or a hung kernel can prevent restoration;
do not interpret this as an unconditional root-preservation guarantee.

The Home app-install button refreshes update metadata at click time. It updates
the manager APK, not automatically the installed root environment or modules.

No new background service or polling is required for the quick-install feature.

## Compact UI (v1.0.3)

The default is light Fraxure (Legacy), migrated once on existing installs before
the activity selects its theme. Navigation is Home / Superuser / Log / Tools.
Home support/follow cards and the Tools local ZIP install button are removed.
Settings expose only Magisk: Zygisk, MagiskHide and its configuration screen.
Hidden preferences keep their defaults on fresh installs and their existing values
on updates; the update does not silently reset Superuser policies.

The Tools trash menu has two confirmed operations. All-module removal marks
`remove` in both `/data/adb/modules/*` and `/data/adb/modules_update/*` (non-hidden
module directories only) so pending updates cannot resurrect a removed module.
Actual removal/uninstall scripts run on the next Magisk boot. Root is not removed;
module-owned files/settings outside those folders are subject to its uninstall
script, not deleted by this UI action. Unsafe symlinks are refused. No automatic
reboot and no new service/polling.

System-su cleanup now persists a pending original RO mount at
`/data/adb/ldmask/system-su-ro-pending` before changing the mount to RW. A second
click attempts restoration rather than treating absent files as proof of recovery.
Effective target mounts are checked even after cleanup by older versions. Writable
or unknown state fails visibly; no silent success. The kernel may still refuse
RO remount; in that case reboot LD and re-check. This is not a blanket guarantee
that mounts can always be restored during a running session.

This source has no KernelSU-style WebUI/script action host. Since v1.0.8, LDLogin
with ui.json has a native gear screen; see docs/module-ui.md. No arbitrary root
commands or config paths can be supplied by module JSON.

## Icon-only actions and direct root install (v1.0.4)

Home's manager title is LDMask. Its install icon is visible only for a known newer
APK version; the current version has no reinstall button. Home entry refreshes
metadata instead of retaining a process-lifetime cache. Failed/offline checks hide
the icon, not claim up-to-date. The click rechecks and avoids an equal/older APK.
No background polling/service added. Magisk always has a single install icon.
Tools removal/restore actions have no visible text, and the install icon appears
only for a newer module that is not already staged/marked for removal. Reboot after
flash is icon-only and explicit. Accessibility descriptions and 48dp targets remain.

The Magisk install icon bypasses the removed method chooser and invokes the same
`FLASH_MAGISK_SYSTEM` / `MagiskInstaller.Direct_system` backend that the old system
method used, with Recovery explicitly false. It refuses without existing root or
when Info reports boot-image root. It never falls back to boot/recovery/slot patching
or emulator fix-env. This is a root/system mutation when the USER clicks it, not
an APK update. No live root reinstall is performed merely to verify this UI change.

## Module identity migration (v1.0.8)

Update LDMask first, install both renamed modules, then explicitly reboot LD once.
Legacy `oneone` and `ktools_zygisk` are retired via Magisk disable/remove flags.
Old `/data/adb/oneone/settings.json` is moved without overwriting an existing
`/data/adb/ldlogin/settings.json`; disabled module state is inherited on the first
migration. Acc.csv and LD-map.txt locations are unchanged. LDLogin remains VNG-only,
with its separate native bot switch labelled LDLogin. Missing/bad config stays
OFF/30/no-log without the old notice. The switch applies after Save while the bot
service is running; Magisk's module switch still has normal reboot semantics.

At v1.0.8, LDMenu's two ABI libraries were unchanged opaque binaries; the surrounding module
ID/metadata/install migration changes do not prove runtime compatibility. Validate
its live menu after reboot before cloning LD. Build LDLogin with
`module-src/ldlogin/build.ps1` (Android NDK r30, x86_64 Android API 28), then package
with `tools/package-modules.ps1`; it verifies the original LDMenu ZIP hash.

## LDMenu pathname/metadata integration (local v1.0.14 test)

Build the ARM wrapper with `module-src/ldmenu/build.ps1` before packaging modules.
LDMenu v1.2 wraps the retained opaque ARM dependency; x86_64 remains unchanged.
The new APK/core and module are paired: installing only the APK does not update
the core or module. Direct-system core install and explicit LD reboot are needed.
The online catalog is not changed by local builds. See
`tests/VERIFICATION-v1.0.14.md` for hashes, build validation and live-test limits.
Reduced LDMenu names/paths are not a guarantee of universal root invisibility.
