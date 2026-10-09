# Native module configuration

Tools → LDLogin gear after installing LDLogin v1.24 from LDMask v1.0.8.
A staged descriptor can also be opened before reboot; settings live outside the
module. Update LDMask first, then install both renamed modules and reboot once.
Legacy IDs are retired and old settings are migrated without overwriting new ones.

The module root contains ui.json. See module-ui/ldlogin.json for schema 1. The host
renders Android native switches and number input; it does not load a web page,
evaluate JS, execute schema commands or accept schema-provided paths.

Only settingsId=ldlogin/module ID=ldlogin is currently registered. Three typed keys
are required: enabled (Boolean/default false), boot_wait_seconds (integer/default30,
0..600) and logging (Boolean/defaultfalse). The bot switch label is LDLogin without
a Bật prefix. There is no game picker: com.vng.playtogether is the only bot target.
Schema is limited to 16KiB, three fields, bounded text and no duplicate/unknown keys.
New module settings backends require code review/explicit host registration.

Data is /data/adb/ldlogin/settings.json. The module native finder reads and saves
it, with chmod0600, fsync and same-directory rename. The host does not invent another
writer. Missing/invalid settings show OFF/30s/no-log without the old notice and are
NOT automatically saved.
Only explicit Save writes data. A changed fingerprint rejects a stale draft; Reload
discards unsaved values and reads the current file. This is an optimistic conflict
check, not a lock shared with every possible external writer.

No config polling/service. Files are read when the screen opens/reloads/saves;
bot uses existing inotify. Boot-delay changes affect the next boot, not an ongoing
boot wait. Bot enable changes apply after Save while the service is running.
Disabling the Magisk module is distinct and retains normal reboot semantics.

Mở Game sits to the right of Tải Lại. Since v1.0.11 it verifies PID plus attached
Activity and foreground state, confirmed twice with the same PID. It protects any
game observed attached/running during the click from force-stop, even if focus
fails. Absent or explicitly INITIALIZING state can be recovered with force-stop
and another root start; unknown/failed dumpsys output is never a reason to kill.
Maximum three start attempts, 20-second verification per attempt, 120-second outer
timeout and short per-command bounds. The worker is serialized process-wide and
buttons remain disabled while running. All launch failures/successes are silent.
No implicit settings save, bot enable, root grant to game or background monitor.

Build module-src/ldlogin with build.ps1, then tools/package-modules.ps1.
Native source changes in v1.0.8 are identity/path renames, not new matching logic.
