# LDMask v1.0.3 verification — 2026-10-09

## Build and packaging

- Full release native rebuild followed by release APK rebuild succeeded.
- Package `io.github.oneone404.ldmask`, label LDMask, version LDMask-1.0.3,
  versionCode 27005, SDK min23/target34, original Kitsune icon retained.
- APK 12,884,639 bytes. SHA256:
  `bee0f345e3190aa396b39adf4e93e87117e48ca3e92666ac22089ce5c3b0e124`.
- APK v1/v2 signature valid. Same local Android debug certificate SHA256
  `dc0754b98e885c80916f5da9eea6ea2aacc2f1f22e09040f4debafbd3c8a2621`.
  Experimental release-mode build, not an audited production signing setup.
- Native generated flags: LDMask-1.0.3 /27005, MAGISK_DEBUG=0.
- All 20 native payloads match stripped-native Gradle outputs (4 ABIs, 5 each).
- Compiled XML checked: Home only two include cards and no support/follow cards;
  quick installer only one Button; compact module layout 13 elements.

## Tests

- JVM: 22 tests (14 quick-installer, 8 source/UI contracts), no errors,
  failures or skips. Includes actual unchanged ZIP pair validation.
- Android `sh -n` on both production cleanup scripts passed.
- Android fixture suite: 13 assertions passed, including absent files, deletion
  plus RO restoration, refused remount, persisted partial result, second click
  still failing, recovery, old-version RW refusal, active+staged removal markers,
  symlink refusal and untouched destination.
- Fixtures ran as Shell, without root, with all target paths rewritten to an
  isolated `/data/local/tmp/ldmask-fixture-*` tree. Root discovery/mount mocked.
  Fixture tree removed. This is NOT a real kernel remount or root deletion test.

## Read-only live observations

ADB connected to the running index2 LDPlayer-2 via 127.0.0.1:5559.
Both `/system/bin/su` and `/system/xbin/su` were absent; `/sbin/su` existed.
`/dev/root /` was RW; `/system/bin` had RO Magisk overlays. This confirms the
reported v1.0.2 second-click success did not prove root-mount restoration.
No live mount change, su deletion, module removal, APK installation, or LD reboot
was executed during this verification. UI appearance/click flows and online APK
installation still require user testing; compiled XML/contracts are not visual QA.

## Release assets

APK plus OneOne.zip, Module.zip, modules.json, update.json and CHANGELOG.md.
Module IDs/versions/bytes/hashes unchanged from v1.0.2. Local shared Module.zip
was absent, so the previously verified v1.0.2 artifact was reused and its SHA256
rechecked. Private signing material, accounts and emulator data are not published.

## Operational limits

System-su deletion can still succeed while RO remount is refused by the kernel.
The new script persists/checks the obligation and refuses misleading success;
it does not guarantee in-session remount recovery. Reboot LD and re-check if the
mount remains RW. No automatic reboot. All-module removal marks active AND staged
folders; actual uninstall executes on next boot, including module-owned uninstall
scripts that may remove their own data. Root is retained. No WebUI host added.
