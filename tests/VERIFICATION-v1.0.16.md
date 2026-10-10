# LDMask v1.0.16 — install dialog labels

Date: 2026-10-10, Asia/Bangkok. Built for GitHub publication; no live LD installation.

- ChooseModulesDialog and ManagerInstallDialog use a dedicated install action string: Vietnamese `Cài đặt`, English `Install`.
- Module selection, quick-install callback and app download callback are unchanged. Configuration screens and flash screen labels remain unchanged.
- Vietnamese loading string is now exactly `Loading`; covered by the existing new label contract test.
- Added a source contract test for both labels and existing action callbacks. 57 JVM tests passed, zero failures/errors/skips; actual module ZIP checks used the unchanged v1.0.15 bundle.
- Full four-ABI release build succeeded; existing toolchain warnings remain.
- APK package: `io.github.oneone404.ldmask`, version `LDMask-1.0.16`, code `27018`.
- APK rebuilt after the loading label change; size: 12,893,054 bytes. SHA256: `69c2018c07dd82004496ad1313edcee8622c1c9d9528c7148a1995a3436ca316`.
- apksigner verification passed with the same certificate as v1.0.15: `dc0754b98e885c80916f5da9eea6ea2aacc2f1f22e09040f4debafbd3c8a2621`. Existing Android Debug certificate and META-INF warnings remain unchanged.
- Shared local APK: `C:\Users\OOP\Documents\XuanZhi9\Pictures\LDMask-v1.0.16.apk`; copied hash matches output APK.
- No runtime, module or root-hiding logic changes. APK update alone applies these label changes.
