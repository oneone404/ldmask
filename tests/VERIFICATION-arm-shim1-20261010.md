# LDMenu ARM shim1, 2026-10-10 — experimental, not fully concealed

## Scope and user acceptance

Only LD index 0 was changed. LD1 was off and left untouched. Existing LDMask
APK/core stayed `LDMask-1.0.13-ldmenu-test5` (27015). Only LDMenu's ARM64 library
was replaced with a wrapper embedding its byte-identical original library.
The user explicitly confirmed: menu and key both work on the new ARM build.
No credentials, game accounts, login data, hide-list or root presets changed.

## Fixture

Standalone unprivileged `ldmenu-arm-import-fixture` passed eight groups, rerun
after the live test: exact import, dynamic pointers, header bounds, symbol/string/
GOT bounds, ambiguity/relocation/dynamic rejection, executable-page refusal,
original pointer and RELRO preservation, cleanup. Synthetic fixtures do not
prove every live concurrency/NativeBridge/ABI scenario.

## Live result

First boot: main 3815, tracer 4148. The previous payload mapping named
`cache/tmp/ktools_loader/library_188_...so` was absent. Original ARM loader
and downloaded ARM payload were mapped through sealed `memfd:jit-cache`.
The user confirmed menu and key. A subsequent enabled boot had main 3492,
tracer 4290, resumed game Activity, and the same mapping/FD-name result.
No root/game-process memory was patched in place and no tracer was killed.

### Tracer control experiment

`ldmenu-tracer-ab.sh off` created only a tagged `ldmenu/disable` flag. After
reboot with this module disabled: game main 3518 still had TracerPid 3805;
the child still had one thread waiting in wait4(main). No LDMenu/payload mapping
matched the metadata checks. Thus TracerPid is not a sufficient indicator of
LDMenu. Its origin (NativeBridge/game/other component) has not been proved.

The exact tagged flag was removed with `on`, LD rebooted again, and module
enabled state plus ARM hash were verified. The script refuses to remove an
unrelated flag. LDLogin and other modules were not changed.

### Remaining limits

- Cached original payload still exists under the game's `ktools_loader` directory.
- ELF content, SONAME/loader state and module's actual behavior were not erased.
- Sealed memfd changes pathname exposure; it is not proof against every detector.
- Memory/CPU overhead of the embedded loader and snapshots has not been benchmarked.
- Repeated game boots, offline/network failure and version-update scenarios still
  require testing before any ordinary release. There was no GitHub publication.

## Recovery and source artifacts

ARM original: 3,328,520 bytes, SHA256
`ecd058d4b55c2c983152f31245285c9159c0895ee987ade5ae9438af1dcecaaf`.
ARM shim1: 3,344,176 bytes, SHA256
`4cf0e7cad0cc89848a6aa5bb5d24486a45931c20b7df9fe7aed71798b43a5069`.
Host copies are in `D:\App\artifacts\ldmenu-hide-trial-20261009`.
Android original: `/data/local/tmp/ldmenu-arm-before-shim1.so`.
`switch-ldmenu-arm-shim1.sh rollback` restores this single library with pinned
hash checks, then requires reboot. It does not roll back LDMask core/APK.

The new `runtime-api-callers.reconstructed.c` has 11 exported runtime functions,
selected through static references to loader/kernel APIs. No direct ptrace caller
was identified there. This remains offline pseudocode, not original/build-ready
project source; existing original/runtime RAM artifacts were preserved.

## Diagnostic caution

Read FD symlink metadata only, never grep/read arbitrary `/proc/PID/fd/*`:
those entries include pipes/sockets/devices. One earlier diagnostic grep blocked
and was explicitly terminated; the metadata script uses `readlink` instead.
