# LDMask tests

`powershell -File tests/test-tools-shell.ps1 -Serial <ADB-serial>` executes Android
shell fixtures without root: all target paths are rewritten into a unique
`/data/local/tmp/ldmask-fixture-*` tree, root discovery and mount are mocked.
It never executes the real mount/su command or touches installed modules. Fixture
cleanup is guarded to the exact generated test tree. This verifies shell control
flow, not a real kernel remount or UI integration.

`gradlew :app:testDebugUnitTest -PconfigPath=config.ldmask.prop`

The quick-installer JVM suite uses fake network/root implementations, so no
module is flashed by the tests. It covers pair prevalidation, malformed/foreign
release assets, hash/ID/path errors, network failure, partial installation,
serialization, and private ZIP cleanup.

Optional real-asset validation: set `LDMASK_RELEASE_FILES` to a directory with
`OneOne.zip`, `Module.zip`, `modules.json` for the release before running tests.
The real-asset test is skipped when the variable is unset.

Actual root installation, MagiskHide, reboot behavior, Android lifecycle and
UI layout still require emulator/device testing. Passing JVM tests does not
prove them. Do not run destructive root tests on production LDs without approval.

`LDMaskUiContractTest` checks source-level contracts for banner removal, the
toolbar action, fixed cleanup targets, root preflight, confirmation and timeout.
It does not execute shell deletion/remount commands or prove their runtime behavior.

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
