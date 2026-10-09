# LDMask v1.0.13 — native MagiskHide startup repair

Date: 2026-10-09, Asia/Bangkok. User authorized fixing and testing the core. No GitHub push/release publication. LD0/Assistant was left untouched. Only comparison LD1 was restarted/updated. No game data/accounts deleted and no hiding module added.

## Cause captured on the original core

LD1 was initially a ghost UI with backend PID -1. Closed its stale UI and launched the same index. Original daemon: LDMask-1.0.10 / 27012, Zygisk=1, Hide=1, SuList=0, VNG main and adnw selected; LDLogin/LDMenu enabled.

Fresh launch started game PID 4017. Across eight one-second observations it remained root-owned zygote64, one thread, TracerPid=0, waiting in read(fd=3, count=4) on a Unix socket. Magisk daemon PID 1376, worker TID 4020, was waiting in read(fd=20, count=4) on pipe inode 29324. Its own write FD 21 still referenced that pipe. Helper PID 4024 was a zombie. ActivityManager then reported failed-to-attach / killing 4017 for start timeout.

The matching `get_clean_ns()` code wrote READY to one pipe, then read ACK from the SAME pipe. The worker can consume its own READY and exit, leaving the daemon blocked: its own pipe write end prevents EOF. This is not a missing SIGCONT hypothesis or a game account problem.

## Fix

- Atomic SOCK_SEQPACKET socketpair with separately closed parent/worker endpoints.
- Worker opens the clean mount namespace and transfers its FD via SCM_RIGHTS. That reference pins the namespace after worker exit: no `/proc/worker/ns` lifetime race or ACK required.
- Uses the daemon's existing detached-worker mechanism, not a new resident service. The FD receive has a 3000 ms monotonic deadline; malformed/EOF/truncated messages fail and unexpected FDs are closed.
- Validates namespace switch/unshare, accepts valid FD 0, uses CLOEXEC, and reports failed creation/setns instead of returning false success.
- Serializes per-ABI namespace cache initialization/reset.
- No weakening of the game hide selection, anonymous module mapping or native Hide settings.

## Automated checks

- Standalone native fixture compiled warning-clean and ran WITHOUT root on both Android x86_64 and x86: eight checks per ABI. Includes deterministic old-pipe self-read, namespace FD survival after worker exit, explicit worker failure/EOF, no SIGPIPE, interrupted deadline, malformed/truncated/multiple descriptor rejection, FD 0 and 100 transfers without FD leaks. It performs no mount or game operations.
- Full release build passed for all four native ABIs plus APK.
- JVM suite forced to re-run: 54 tests, zero failures/skips, including actual unchanged LDLogin/LDMenu release ZIPs. One preliminary optional-assets attempt used the source release metadata folder, which lacks ZIPs, and failed with Invalid asset size; corrected to `D:/App/artifacts/ldmask-v1.0.12`, then all passed. No test assertion or production validator weakened.
- `git diff --check` passed. apksigner verified unchanged experimental Android debug certificate; pre-existing META-INF signing warnings remain. Not a security audit.

## Live launches with native Hide ON

Tests require a stable PID attached to a resumed foreground Activity across two observations. Ready times include deliberate sampling delay; not gameplay rendering/authentication speed benchmarks.

| Boot | Build | Run/PID | Ready seconds |
| --- | --- | --- | --- |
| 38b1ae1b-9bd5-4bfc-b718-eb95af6544ef | 1.0.13-hidetest1 / 27014 | 1 / 4554 | 4.32 |
| same | same | 2 / 4963 | 4.31 |
| same | same | 3 / 5263 | 4.36 |
| same | same | 4 / 5586 | 4.35 |
| same | same | 5 / 5892 | 4.47 |
| 2c08d6fc-ac22-48ba-81f0-362a201c3e70 | packaged 1.0.13 / 27015 | 1 / 2995 | 4.71 |
| same | same | 2 / 4567 | 4.50 |
| same | same | 3 / 5014 | 4.39 |
| same | same | 4 / 5351 | 4.54 |
| same | same | 5 / 5669 | 4.39 |

10/10 passed across two reboots, including first namespace initialization. No VNG start-timeout or fatal crash markers after the patched boots.

Also tested the ORIGINAL Android launcher icon, not a root-am shortcut: selected its exact node from uiautomator HOME dump, tapped icon bounds [282,94][414,196], with a fresh force-stop each time. 3/3 passed: PIDs 7890, 8277, 8612. ActivityManager confirmed all three starts came from launcher UID 10052, with MAIN/LAUNCHER and those icon bounds. Final game left open.

## Hiding observations and limits

On both patched samples, main/companion maps had NO jit-zygisk-cache matches; game mountinfo had NO Magisk/module/worker mount matches. /sbin/su and /sbin/magisk were absent in its namespace; system/bin/su was only a dangling ../xbin/su link. LDMenu's arm64-v8a.so remains in the native-bridge companion, and ktools_loader remains in the main game. Modules stayed enabled and their libraries loaded; interactive menu behavior was not independently exercised.

Root-view ro.debuggable=1, ro.secure=1, ro.boot.selinux=permissive, actual SELinux enforcement=0. Assistant ldfix2 previously improved the property/permission side but retained jit-zygisk-cache. Therefore this fixes launch reliability and retains native mapping concealment, not a claim that native Hide wins every detector or root is undetectable. No detector APK was installed and no game/server detection verdict inferred. No hours-long stability/CPU benchmark.

Earlier Shamiko 0.7.5 attach failure occurred on the OLD core. It may have used the same faulty unmount path; causality for that module is not independently proven. Re-test on this core before attributing failure to Shamiko itself or ranking it finally. Latest Shamiko's explicit unsupported-environment result also has not been re-tested here.

## Final installed/distributed state

APK package io.github.oneone404.ldmask, LDMask-1.0.13 / 27015, 12884862 bytes.
SHA256: C08A422BBC0D96FC538111C2527794BB2A0301CDC84C5FB0411817E302AC82CF.

- APK installed in LD1; two persistent core executables updated with hash preflights, prepared same-filesystem replacements and exact rollback copies, then explicitly rebooted. Running /sbin/magisk64 hash matches the actual APK's x86_64 libmagisk64.so. Unrelated init/policy/module/game files were not overwritten by the narrow core test update.
- Packaged x86 core SHA256: 18C301EE43636A345BD671BEFB3C3824F7E11E6079C6C1343F0B6D30FCF77C14.
- Packaged x86_64 core SHA256: B7BCE3E50633CEF317A4827E0BF52547872E4BF1A234B6E44375DD0B31638325.
- Final Zygisk=1 / MagiskHide=1 / SuList=0, VNG main and adnw selections unchanged. LDLogin v1.24 and LDMenu v1.1 enabled, no Assistant/Shamiko on LD1. /dev/root mounted RO after both updates/reboots.
- Native fixture, uploaded old/test/final binaries and HOME XML removed only at their exact test paths. Original LD1 binaries retained on Windows in `D:/App/artifacts/magiskhide-fix-20261009` for rollback.
- Local APK: `releases/v1.0.13/LDMask.apk`; shared copy `C:/Users/OOP/Documents/XuanZhi9/Pictures/LDMask-v1.0.13.apk`, matching hash. Existing shared APKs were not overwritten.
- LD0 retained its original backend/session and Assistant ldfix2. No release or module integration published.

Installing the APK alone on another LD does NOT update that LD's installed core. Its Home Magisk direct-install action followed by an explicit LD reboot is required to activate the native fix there.
