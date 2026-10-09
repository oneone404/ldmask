# LDMenu path-hiding experiments — 2026-10-09/10

Historical phases below: experimental, partial result only. Not released or integrated into the
ordinary LDMask APK. LD0 was not changed. The user confirmed LD1's menu is visible
and usable on the second experiment. This does not establish undetectability,
server acceptance or a complete root-hiding result.

## Existing stable startup fix

Keep the bounded namespace-FD handoff in LDMask 1.0.13 (27015), documented in
VERIFICATION-v1.0.13.md. It is independent of these opt-in experiments.

## First approach: post-callback remapping

config.ldmenu-test.prop enables LDMENU_HIDE_EXPERIMENT. The helper restricts
paths, size, protection and thread count before replacing readonly mappings.
The effective live probe found the target, but the process was already
multithreaded: found=1, changed=0, single=0. It correctly refused the replacement.
Earlier binaries lacking flags.h did not enable the experiment and are controls,
not evidence of feature success. This approach was not promoted.

## Second approach: pre-mapping immutable snapshots

config.ldmenu-loader-test.prop enables LDMENU_LOADER_EXPERIMENT on x86_64.
It hooks the already-loaded NativeBridge callback table and the exact LDMenu
native library's mmap import. Exact target ELF data can be backed by a sealed
memfd before mapping; original loading remains the fallback. No periodic scanner
or live rewrite of multithreaded game mappings is introduced.

The snapshot helper limits files to 16 MiB, total allocated snapshots to 32 MiB,
and cache slots to eight. File identity, timestamps, retained FD identity and
source changes are checked. The fork guard protects the cache mutex. Callback
code remains mapped for process lifetime; retained code and snapshots have a
memory cost. CPU/RAM overhead has NOT been benchmarked.

### Observed live outcome on LD1

- Core: LDMask-1.0.13-ldmenu-test2, code 27015.
- NativeBridge v3 hook and exact module mmap hook were installed.
- Companion ARM64 mapping previously named
  /data/adb/modules/ldmenu/zygisk/arm64-v8a.so now appears as
  /memfd:jit-cache (deleted). Confirmed across different game PIDs.
- Main game still maps its cache/tmp/ktools_loader/library_*.so pathname.
  The external NativeBridge callbacks have not hidden this guest-side load.
  Bypassing those callbacks internally is a working hypothesis, not proof.
- Latest read-only probe: game PID 6420 and companion PID 6541; same partial
  result. The user confirmed the menu is currently usable.
- No further game stop/reboot was done after that user confirmation.

Only path visibility in privileged maps was measured. Other detection surfaces,
menu contents, code fingerprints and game/server verdicts were not eliminated
or exhaustively tested. No runtime source recovery or RAM dump was performed.

### Offline fixture verification

tests/ldmenu_fd_test.cpp: nine checks passed on LD1 as an unprivileged standalone
x86_64 process, without stopping the game or changing bot settings:

1. Exact ELF snapshot bytes.
2. Write/grow/shrink seals.
3. Bounded cache reuse and memfd pathname.
4. Regeneration after a retained FD is closed.
5. Supplied source FD offset is unchanged.
6. Nanosecond modification invalidates cached snapshot.
7. Snapshot byte budget refuses new allocation.
8. Wrong ELF architecture is rejected.
9. Missing/nonregular source refusal and fixture cleanup.

These checks do not prove every loader or concurrency path safe.

## Installed artifacts and compatibility caveat

Current experiment binaries are preserved outside ordinary native build outputs:
D:/App/artifacts/ldmenu-hide-trial-20261009/test2-mmap-magisk32 and
test2-mmap-magisk64.

SHA-256:

- x86: d27c6ad909400dc7b20eabb222b4060902be2aa8830f9707bf2d2872a059e2d9
- x86_64: 697b3b0253e24bee4a0f99fdacef78f4044933d066bab23f86e58c65c505fcd2

LD1 still has the ordinary 1.0.13 APK/support version and the experimental core
version. This is NOT a matched release and may trigger additional setup.
Do not instruct the user to accept setup blindly: it can overwrite trial files.
Before deployment, either build/test a matched package or explicitly restore the
stable core. Restoring the persistent binaries requires a coordinated LD1 reboot
to activate; do not interrupt the user's active menu session automatically.

The install-ldmenu-trial.sh helper has pinned current trial/stable hashes and a
rollback mode. Preserve its exact uploaded rollback binaries until the live
experiment is retired. Nothing was committed, pushed or published to GitHub.

## Third experiment: Android data-directory alias

On 2026-10-10 the user authorized one more LD1 reboot and launch test. Added only
the exact /data/user/0/com.vng.playtogether cache prefix to the target allowlist,
with negative cases for other users/packages and path traversal. The standalone
path/remapping fixture passed all four groups. The live device resolves this
prefix to /data/data/com.vng.playtogether. The cached loader ELF machine is
EM_AARCH64, confirmed from header fields only, not a RAM dump/source recovery.

Current live core is now LDMask-1.0.13-ldmenu-test3 (27015), replacing test2.
Boot ID: 4e12edc9-8edc-4306-ad11-058faf0184e7.
Three normal Activity launch tests reached stable attached/resumed state:
PID 3782 in 4.37 s, PID 5019 in 4.40 s, PID 5328 in 4.28 s. These durations include
the fixture's deliberate stable-state observation interval, not pure launch time.
No VNG attach timeout was seen. Crash buffer contained a separate partnersetup
SIGSEGV: do NOT interpret that as a game crash or claim the buffer was empty.

After menu loading, PID 5328 still had the original ktools_loader pathname;
tracer PID 5458 retained the memfd:jit-cache ARM mapping. The alias hypothesis did
not produce any additional hiding. The main game reported TracerPid=5458, which
is another observable artifact independent of library paths. No full detection
resistance is established. Menu usability was user-confirmed for test2, not yet
user-confirmed for test3. LD0's backend/UI PIDs stayed unchanged during the test.

Preserved current binaries:
D:/App/artifacts/ldmenu-hide-trial-20261009/test3-alias-magisk32 and
test3-alias-magisk64.

- x86 SHA-256: fea3ef011190653a8a3f9a1c913ca7876a5894d35a241ff770370371987ccb5a
- x86_64 SHA-256: 37577e0f62eda5f603ed602cb33c009ce68fcd1846e5f0bdd2294324aac6c9d1

The ordinary APK/support mismatch caveat still applies. Current installer hashes
are pinned to test3 and accept either test2 or the stable core as an install base.
Rollback still restores the stable core and requires a coordinated reboot.
Do not blindly accept additional-setup prompts while evaluating this trial.
No trial APK/release has been published. Normal native outputs are rebuilt with
config.ldmask.prop after artifact preservation to prevent accidental packaging
of trial code into the ordinary APK. This does not change the running LD1 core.

## Current continuation on LD0 — 2026-10-10

The user subsequently authorized RAM/source recovery, selected a matched test3
APK/core on LD0, and confirmed game startup, menu and key authentication work.
See `VERIFICATION-ld0-test3-20261010.md` for the installation identity. The
earlier "LD0 unchanged" and source-recovery deferral statements below/above
describe their historical phase, not the current authorization/state.

The user challenged attribution of the test5 timeout to the patch. It remains
unproven; test5 was rebuilt with matching APK/core/support and installed/rebooted
on index 0 for a fresh acceptance test. Live core is test5, 27015, with resumed
game Activity; key/menu confirmation is still pending. Hide/Zygisk flags, VNG
hide-list and LDMenu/LDLogin remain unchanged. LD1 remained stopped.

Read-only library RAM capture and offline reconstruction have now been performed.
Exact decrypted ARM code is preserved, and initial C-like pseudocode/loader API
callers exported. Original project/source has NOT been recovered, JNI runtime
decompilation remains incomplete, and concealment remains partial. Full current
results and caveats are in
`D:/App/artifacts/ldmenu-source-recovery-20261010/README.md`.

## Follow-up boundary: full concealment request

Read-only follow-up still found game PID 5328, TracerPid 5458 and the five cached
loader mappings. Tracer 5458 reported syscall 61 (x86_64 wait4), first argument
0x14d0 = 5328. This establishes a continuing tracer relationship at observation
time, not just a historical library pathname. It does not prove why LDMenu keeps
that relationship or whether detaching it would preserve functionality.

Do not kill/detach the tracer or rewrite writable live mappings to make a hiding
test pass. No such operation was performed. Removing pathname markers alone is
not full concealment. The available LDMenu payload is binary-only; customize.sh
contains installation/ID migration, not its runtime loader source. Further
runtime payload/source-recovery work was previously deferred by the user and
should be explicitly clarified before starting that distinct investigation.
