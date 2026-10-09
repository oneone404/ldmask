# Native module configuration

Tools → OneOne gear, after installing OneOne v1.23 from this LDMask release and
activating it by reboot. A staged descriptor can also be opened before reboot;
settings are shared outside the module. Older OneOne ZIPs without ui.json have no gear.

The module root contains ui.json. See module-ui/oneone.json for schema 1. The host
renders Android native switches and number input; it does not load a web page,
evaluate JS, execute schema commands or accept schema-provided paths.

Only settingsId=oneone/module ID=oneone is currently registered. Three typed keys
are required: enabled (Boolean/default false), boot_wait_seconds (integer/default30,
0..600) and logging (Boolean/defaultfalse). Label/order are declared by the JSON.
Schema is limited to 16KiB, three fields, bounded text and no duplicate/unknown keys.
New module settings backends require code review/explicit host registration.

Data remains /data/adb/oneone/settings.json. Existing native finder reads and saves
it, with chmod0600, fsync and same-directory rename. The host does not invent another
writer. Missing/invalid settings show OFF/30s/no-log and are NOT automatically saved.
Only explicit Save writes data. A changed fingerprint rejects a stale draft; Reload
discards unsaved values and reads the current file. This is an optimistic conflict
check, not a lock shared with every possible external writer.

No config polling/service. Files are read when the screen opens/reloads/saves;
bot uses existing inotify. Boot-delay changes affect the next boot, not an ongoing
boot wait. Disabling the Magisk module is distinct from disabling bot in its config.

Package the descriptor with tools/package-oneone-ui.ps1 using the exact verified
v1.22 base ZIP. It creates v1.23 with only module.prop/ui.json changed and refuses
unknown base or existing output. Existing dirty modulelogin work is not overwritten.
