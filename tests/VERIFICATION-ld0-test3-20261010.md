# LD index 0: test3 installed, 2026-10-10

User selected the third trial (partial LDMenu concealment), not the later
test5 build associated with slow menu/key-authentication timeouts.

Installed APK and updated the existing system-mode native installation. No
boot/SELinux policy reconstruction, module changes, account deletion, or
hide-list edits were performed. Only LD index 0 was rebooted. LD1 remained off.

## Verified after reboot

- Live daemon: `LDMask-1.0.13-ldmenu-test3:MAGISK:R`, code 27015.
- APK: `io.github.oneone404.ldmask`, same version/code.
- Utility assets: same version/code as the APK and daemon.
- Root Shell works; Android boot completed.
- Zygisk=1, MagiskHide=1, SuList=0 preserved.
- Existing VNG main and `:adnw` hide-list entries preserved.
- LDMenu v1.1 and LDLogin v1.24 remain enabled, not marked for removal.
- Root filesystem read-only after reboot.
- Game processes present after reboot (4641, 4763); this alone does not prove
  menu/key authentication is successful. User acceptance testing remains.

## Artifact identity

APK: `D:\App\artifacts\ldmenu-hide-trial-20261009\LDMask-ldmenu-test3.apk`

Shared copy: `C:\Users\OOP\Documents\XuanZhi9\Pictures\LDMask-test3.apk`

APK SHA256: `8d61dfb88f3610ccaf20fe27b147dff169a2161878336574cf00eee6aee76e7e`.

Both persistent and data-support native cores match the exact previously
tested test3 binaries, checked before and after reboot:

- x86: `fea3ef011190653a8a3f9a1c913ca7876a5894d35a241ff770370371987ccb5a`.
- x86_64: `37577e0f62eda5f603ed602cb33c009ce68fcd1846e5f0bdd2294324aac6c9d1`.

Original core/support backups are in the host artifact directory and
`/data/local/tmp/ldmask-ld0-test3-backup-20261010` on this LD. The stable
release APK was not overwritten. Normal native build outputs currently
contain this trial; rebuild with the stable config before any stable release.

This is partial concealment only; no claim of complete LDMenu invisibility.
