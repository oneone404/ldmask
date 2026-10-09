# LDMask tests

`powershell -File tests/test-tools-shell.ps1 -Serial <ADB-serial>` executes Android
shell fixtures without root: all target paths are rewritten into a unique
`/data/local/tmp/ldmask-fixture-*` tree, root discovery and mount are mocked.
It never executes the real mount/su command or touches installed modules. Fixture
cleanup is guarded to the exact generated test tree. This verifies shell control
flow, not a real kernel remount or UI integration.

Since v1.0.12, the removal worker separately verifies both fixed Su paths are
absent (including symlinks) and independent Magisk root works. The UI reports
verified deletion as success even if the cleanup script could not restore a
read-only mount; warnings and its pending mount state remain intact. The fixture
also tests this verifier with writable mounts, remaining files and dangling links.

`gradlew :app:testDebugUnitTest -PconfigPath=config.ldmask.prop`

The quick-installer JVM suite uses fake network/root implementations, so no
module is flashed by the tests. It covers pair prevalidation, malformed/foreign
release assets, hash/ID/path errors, network failure, partial installation,
serialization, and private ZIP cleanup.

Optional real-asset validation: set `LDMASK_RELEASE_FILES` to a directory with
`LDLogin.zip`, `LDMenu.zip`, `modules.json` for the release before running tests.
The real-asset test is skipped when the variable is unset.

Actual root installation, MagiskHide, reboot behavior, Android lifecycle and
UI layout still require emulator/device testing. Passing JVM tests does not
prove them. Do not run destructive root tests on production LDs without approval.

`LDMaskUiContractTest` checks source-level contracts for banner removal, the
toolbar action, fixed cleanup targets, root preflight, confirmation and timeout.
It does not execute shell deletion/remount commands or prove their runtime behavior.

## Native settings and server selection (v1.0.6)

ModuleUiSchemaTest validates the actual LDLogin descriptor, typed/default/ranged
settings and rejection of commands/paths/duplicates/unknown properties. Host UI
contracts cover native widgets, fixed backend, icon-only uninstall and compact cards.
QuickModuleInstallTest adds single-selection and fail-closed publication cases.

tests/test-native-settings.ps1 runs the identity-renamed module finder without root in an
exact generated /data/local/tmp/ldmask-settings-fixture-* directory. It verifies
missing/invalid settings defaults, writer round-trip, range rejection and symlink
write refusal, then cleans only the validated fixture directory. Real bot settings
and accounts are not touched. Android UI/root-repository click integration still
requires user testing; these tests do not claim visual or live bot activation QA.

## ID migration and unlisted module cleanup (v1.0.8)

`powershell -File tests/test-module-migration.ps1 -Serial <ADB-serial>` runs actual
migration/cleanup scripts with rewritten paths and mocked UID in a unique non-root
Android fixture. It covers settings preservation/no overwrite, active and staged
legacy retirement, disabled-state inheritance/reinstall, full server-list cleanup,
unpublished modules, symlink preflight and empty-allowlist rejection. It never
changes real modules or bot settings. JVM tests verify cleanup is called only after
all selected installs succeed and preserves published but unselected modules.
These tests do not prove LDMenu's opaque library works after a real ID migration.

## Root game launch (v1.0.10)

`powershell -File tests/test-game-launch.ps1 -Serial <ADB-serial>` runs the actual
launch script with all UID/package/activity commands mocked and a simulated clock.
Eighteen cases cover running-game protection, startup recovery, concurrent healthy
transition, failed focus/disappearance, missing/failed dump format, maximum attempts,
stop failure, missing root/game, command errors and no false success. It never
launches/stops/modifies the real game. UI contracts check button position, busy and
process-wide guards, IO/root/timeouts, readiness verification and silent failure.

## Post-root preset (v1.0.5)

Only after successful direct-system root installation, preset Zygisk=1,
MagiskHide=1 and SuList=0. Installed Play Together VNG/Haegin packages and their
manifest processes are added to hidelist, leaving other entries/policies intact.
Absent games are skipped. A later game installation does not automatically hide it;
use Cấu Hình MagiskHide or deliberately run root installation again.

Root-owned atomic `/data/adb/post-fs-data.d/ldmask-root-preset.sh` applies before
this fork reads Zygisk/Hide flags on next normal boot. It verifies data before
self-removal; failures/safe-mode retain it. Existing-daemon persistence has a bounded
timeout, but activation still requires explicit reboot. No forced daemon/zygote
restart, automatic reboot, resident service or polling.

`LDMaskRootPresetPlanTest` validates package/process allowlists and hook contracts.
`powershell -File tests/test-root-preset.ps1` uses the actual compiled planner,
SQLite in RAM and non-root Android syntax/mock control-flow tests. No real root
operations are performed. Live root/Hide/Zygisk integration still requires testing.
