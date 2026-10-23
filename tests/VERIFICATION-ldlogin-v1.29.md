# LDLogin 1.29 — login-only template cache

Date: 2026-10-23, Asia/Bangkok.

## Scope

- Login-only mode uses one native child and two private FIFOs, with shell builtin request/reply IO. No per-scan finder process is spawned on the healthy cached path.
- Only decoded LOGIN/CONFIRM/OK templates persist. Each request obtains a fresh screenshot; thresholds, ROIs, action validation, five-second scan wait, account transaction, and full FramLogin behavior remain unchanged.
- Cached entries are bounded to three. File device/inode/size/mtime/ctime (including nanoseconds) are compared each scan. Decode is accepted only when before/after snapshots agree. Missing/corrupt/replaced templates do not reuse old images.
- Worker is started lazily, blocks idle on its input FIFO, and is stopped on master OFF, transition to FramLogin, or script exit. Kernel parent-death signal also terminates the worker. Cleanup only signals the exact unreaped child of the app shell.
- An eight-second response timeout discards the worker, IPC directory and partial/pending result before the existing one-shot fallback is attempted. Existing gate checks still run before and after scans and before input/account operations.
- Config watcher explicitly closes matcher FIFO descriptors when spawned. No settings schema/APK/root-core changes.

## Verification

- Android tests used emulator-5556 (LD-1), ordinary shell, generated 960x540 template-only frames, exact random scratch directories and mocked inputs. No installed module/settings/accounts were modified, no live game action/reboot was performed.
- Native full/login-only matcher regressions and config watcher/FIFO/dependency fixtures passed.
- Persistent matcher fixtures passed: repeated frames retain one PID; six scans decode exactly three templates total (15 cache hits), fresh frames match LOGIN/CONFIRM/OK and reject BALO/MENU; file replacement/corruption/deletion/restoration/metadata changes invalidate correctly; watcher coexists without inheriting matcher descriptors; OFF notification still arrives; stop/restart/killed worker/capture failure/timeout/parent-death cases work; idle worker does not scan.
- One generated-frame worker RSS observation was 3,344 kB. This is not a production CPU or memory-saving benchmark; the resident matcher trades a small retained working set for fewer launches/PNG decodes.
- Production main-loop fixture passed all 15 cases, including cached results without one-shot invocation and master OFF after a cached result blocking input/account access. Action-function fixture and packaged-native settings round trips passed.
- 70 JVM tests passed (0 failures/errors/skips), including actual packaged release asset validation and cache/gate source contracts.
- Android shell syntax and git whitespace checks passed.

## Package

Release `ldlogin-v1.29` contains all nine app/catalog/update/module assets.

- LDLogin v1.29 / versionCode 30.
- LDLogin.zip: 162,468 bytes, SHA256 `02f84139d473822096e8a42bd357bc20d355795a02dcc10de9a040deb35189d3`.
- Native finder: 210,720 bytes, SHA256 `7980d24baace75069e631769f79c3e6c8f72834737b9e38919626baaafaeb80ce`.
- LDMask.apk 1.0.19 / 27021, LDMenu.zip and LDNPH.zip match published 1.28 assets byte-for-byte. Catalog lengths/hashes match all three module ZIPs.

Update only LDLogin and reboot LD once to activate the new script. No APK update or re-root required. Long-running production compatibility/CPU measurements are not claimed by these tests.
