# LDMask tests

`gradlew :app:testDebugUnitTest -PconfigPath=config.ldmask.prop`

The quick-installer JVM suite uses fake network/root implementations, so no
module is flashed by the tests. It covers pair prevalidation, malformed/foreign
release assets, hash/ID/path errors, network failure, partial installation,
serialization, and private ZIP cleanup.

Optional real-asset validation: set `LDMASK_RELEASE_FILES` to a directory with
`OneOne.zip`, `Module.zip`, `modules.json` matching v1.0.0 before running tests.
The real-asset test is skipped when the variable is unset.

Actual root installation, MagiskHide, reboot behavior, Android lifecycle and
UI layout still require emulator/device testing. Passing JVM tests does not
prove them. Do not run destructive root tests on production LDs without approval.
