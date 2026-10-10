# LDMask v1.0.15 — foreign SU status dialog

Date: 2026-10-10, Asia/Bangkok.

## Behavior

- Only MainActivity's existing non-Magisk PATH SU warning changes. Detection condition is unchanged; EnvFixDialog and other unsupported-environment dialogs are unchanged.
- Vietnamese title: `Thông Báo Trạng Thái`.
- Vietnamese message: `Lệnh SU Không Thuộc Về Magisk Đã Được Tìm Thấy`.
- OK dismisses. DELETE routes directly to the existing `REMOVE_SYSTEM_SU` flash task. No new shell deletion code, reboot or second confirmation.
- Existing fixed targets, independent Magisk root preflight, bounded worker, deletion verification and mount-restoration warnings remain in effect.

## Validation

- Full four-ABI release build and APK assemble succeeded.
- 56 JVM tests, zero failures/errors/skips, including two new popup UI contract tests and actual module ZIP validation.
- Package `io.github.oneone404.ldmask`, version `LDMask-1.0.15`, code `27017`.
- APK size: 12,893,054 bytes; SHA256: `2e3947a1429e8b35166aa96203ab35c2e1ff1777c74de994b9d54d6413c76aab`.
- apksigner verification succeeded. Certificate SHA256 `dc0754b98e885c80916f5da9eea6ea2aacc2f1f22e09040f4debafbd3c8a2621`, unchanged from v1.0.14. Existing Android Debug certificate and META-INF verification warnings remain; this change does not replace the signing setup.
- LDLogin.zip and LDMenu.zip copied byte-for-byte from v1.0.14; manifest sizes and hashes retained. Catalog publication settings unchanged.

## Boundary

No live APK installation, SU deletion or LD reboot during this change. Source tests do not replace live UI/deletion verification. APK update alone applies this popup change; no core or module reinstallation is required for it.
