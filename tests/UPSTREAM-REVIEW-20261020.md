# Kitsune upstream review — 2026-10-20

Read-only remote metadata/source inspection; no upstream merges or core behavior changes.

## Existing base

- `upstream` is https://github.com/zcg9783/KitsuneMagisk1, an archive of v20240705.
- Remote master is `ce81d9916d5a808567f4b31481ac840e4c21fc82`, identical to local upstream/master, already an ancestor of LDMask.
- No newer commit or release in this configured upstream. GitHub's pushed_at is 2024-12-07; the old HuskyDG/magisk-files URL currently returns 404.

## Other fork checked

- https://github.com/1q23lyc45/KitsuneMagisk is archived and has a sunset notice dated 2025-08-24. Current branch kitsune, tip `8e854f378ebabe427f02d65615ddee57af5b53d0`.
- Its final commit changes the advertised Magisk version to 31.0; that does not itself establish equivalent core capabilities.
- Commit `c30ba784ca42da45977bc5ffeeda6e59cf9f7a47` conditionally skips zygote SELinux-context checks only when SELinux is disabled, targeting Waydroid/other SELinux-disabled environments. Disabled SELinux is not the same as permissive SELinux; this is not a demonstrated fix for the measured LD case.
- Commit `bf20079f4fd81db70d7837b6e2c0cc6c1fdf1976` explicitly skips the Zygisk check in its AVD tests because Zygisk is unavailable in that fork. Do not replace LDMask's working Zygisk/LDMenu core with this fork without a separate compatibility project.
- No verified, LD-specific improvement was selected for integration in this feature build. This is not a full vulnerability audit or a claim that every other upstream commit has been reviewed.

Primary sources:

- https://github.com/zcg9783/KitsuneMagisk1
- https://github.com/1q23lyc45/KitsuneMagisk
- https://github.com/1q23lyc45/KitsuneMagisk/commit/c30ba784ca42da45977bc5ffeeda6e59cf9f7a47
- https://github.com/1q23lyc45/KitsuneMagisk/commit/bf20079f4fd81db70d7837b6e2c0cc6c1fdf1976
