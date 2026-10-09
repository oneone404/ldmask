# LDMask v1.0.12 verification — 2026-10-09

- Full native/release build successful. Package `io.github.oneone404.ldmask`,
  version `LDMask-1.0.12` / `27014`.
- APK 12,888,958 bytes; SHA-256
  `57b2c63792561195cec86d1dcd5f926ef9f4d3932c9b1d2f4d164a69376bd9e3`.
- apksigner verification passed with the unchanged experimental Android debug
  certificate. Existing META-INF signing warnings remain; this is not a security audit.
- JVM suite: 54 tests, zero failures/skips, including real release module ZIP hashes.
  New source contracts cover removal of the Tools empty-state message and independent
  deletion verification instead of equating remount failure with deletion failure.
- Non-root Android tools fixture: 19 cases passed on `127.0.0.1:5555`.
  All file targets are rewritten into a unique fixture directory; root discovery,
  independent Su and mount are mocked. No real root/system/module operation occurred.
- New verifier passes after simulated failed read-only remount with both files gone,
  and with an already-writable mount. It rejects a remaining file, a dangling Su
  symlink and missing independent Magisk Su. The pending mount-recovery marker and
  existing cleanup warnings remain intact; no remount failure is hidden in the log.
- The deletion UI now reports success only if the separately bounded verifier sees
  both `/system/bin/su` and `/system/xbin/su` absent and independent Magisk root works.
  Cleanup/remount exit status alone does not decide success. No unconditional success.
- New verifier is present in the packaged APK. Shared Pictures APK copy hash matches.
  No new background monitor, APK/module installation, real Su deletion or LD reboot
  was performed. Visual click integration still requires the user-installed APK.
- LDLogin/LDMenu ZIPs and the root preset are unchanged. Read-only diagnosis on the
  running LD found Zygisk/Hide enabled, VNG main/:adnw in hidelist, only LDLogin
  installed, and `/system/bin/su` present at that moment.
- User reports disabling MagiskHide restored fast normal game launch, but asked to
  defer MagiskHide changes/discussion. No Hide/Zygisk setting was changed by this work;
  the underlying compatibility issue is not claimed fixed by this UI/cleanup release.
