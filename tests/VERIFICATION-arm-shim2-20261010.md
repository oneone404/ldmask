# LDMenu ARM shim2, 2026-10-10 — pathname/SONAME experiment

LD index 0 only; LDMask test5 APK/core, Hide/Zygisk settings, LDLogin settings
and credentials unchanged. LD1 was not modified: initially off, the last read-only
list showed it running. No index-1 launch/update command was issued. No GitHub publication.

## Changes

- Loader-only import hooks redirect exact VNG `cache/tmp/ktools_loader` paths
  and the `/data/user/0` alias to `.runtime`. Unrelated packages, prefix
  lookalikes, traversal and oversized paths are not redirected.
- Atomic `renameat2(RENAME_NOREPLACE)` preserves payload and loader_meta.json.
  No payload deletion, cache merge or forced download. Symlink/conflicting/
  foreign-owned caches refuse migration and legacy paths remain usable.
- Original ELF files stay byte-identical. Private sealed memfd copies receive
  same-length DT_SONAME changes: libLoaderZygisk.so → libNativeBridge.so,
  libktools.so → libnative.so. No instruction/auth/live-RAM/ptrace patches.
- No new background threads or polling. Long-run CPU/RAM not benchmarked.

**Not complete invisibility:** cached ELF contents, remaining filenames/metadata,
code fingerprints and behavior still exist. Neutral paths/SONAME reduce explicit
names; they do not prove resistance to every detector. Offline startup, module
updates, first installation and sustained operation still require testing.

## Tests and live observations

Six unprivileged Android fixture groups passed: path boundaries; atomic cache
migration/rollback with inode/ownership/mode/mtime/bytes preserved; conflicts and
symlinks; open/openat optional variadic mode forwarding; real original ARM ELF
copy comparison; transform cache identity/failure/budget and embedded snapshot.
Existing immutable-snapshot fixture passed all nine cases after API extension.

Initial live build: 3,350,552 bytes, SHA256
`860462df64d22af79d8c1bf0e26abc6744889a6394a1805da0c51073afe60e72`.
Main 3224/tracer 3578: legacy cache absent, both ARM memfds showed neutral
SONAME=1, legacy SONAME=0, sealed=1. **User confirmed menu and key normal.**

Final source-aligned rebuild added the read-only metadata-check API used by
diagnostics; production replacements retain write=true. Installed 3,350,600
bytes, SHA256
`5916e728bbc8f71d411d88cd8841f28d19155fd8da475e6a316fde9781de11f0`.
Another reboot/open: main 3521/tracer 3790, both ARM libraries loaded and the
same two neutral/sealed results. Legacy cache absent; original hashes/mtimes
retained. Resumed Activity sampled was VNG SDK MainActivity: not an independent
final gameplay/key-authentication acceptance test. Tracer left untouched.

Payload SHA256 before/after:
`806aa5dc667b701f3b564d682e4a3f2eda6162de587bcd9ed35e2a337dbd56f2`.
Loader metadata SHA256 before/after:
`ba7b6598c37482cc8de8a9cb3cb27dc9de7de76cc9803f12c6e64f6acbf4bf0e`.
Both original mtimes: 1791557406. No metadata contents/keys printed.

## Recovery and source

`switch-ldmenu-arm-shim2.sh rollback` force-stops only this game, calls the pinned
root-only restore helper to atomically restore the cache pathname without
overwriting conflicts, and restores ARM shim1. Reboot required. The backup
SHA256 is `4cf0e7cad0cc89848a6aa5bb5d24486a45931c20b7df9fe7aed71798b43a5069`.
Recovery paths are fixed in the switch script; host artifact copies also remain.

After tests, 29 exact test/staging/recovery entries created by this work were
moved out of `/data/local/tmp` into `/data/adb/.ldmask-tests-20261010` (root-owned,
0700). Original bytes/backup attributes retained; no recursive deletion. ARM
switch scripts now use this private recovery path. Three temporary copy/move
scripts were removed after use and their source remains on the host. Historical
LDMask core installer scripts are archived records: re-stage their expected
paths from host before reuse. The live APK/core/module path was not moved.

Host first build: artifacts/ldmenu-hide-trial-20261009/ldmenu-arm-shim2.so.
Host final build: artifacts/ldmenu-hide-trial-20261009/ldmenu-arm-shim2-final.so.
NDK API28 Clang, C++17/O2/PIC/shared, no exceptions/RTTI, static-libstdc++,
RELRO/NOW, SONAME libjit-loader.so, libdl/liblog; compile ldmenu_arm_shim2.cpp
and ldmenu_embedded.S, then llvm-strip. Assembly embeds the retained original
ARM binary: this is an addon, not recovered original project source.
