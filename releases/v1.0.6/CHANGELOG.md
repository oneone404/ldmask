# LDMask 1.0.6

- Native module configuration screen, without WebView/JavaScript or a background
  service. OneOne gear opens Boolean/integer controls described by module ui.json.
- OneOne v1.23 /24 adds only the descriptor and version to the verified v1.22 ZIP.
  Finder/bot binaries/scripts unchanged. ktools ZIP unchanged.
- Settings remain /data/adb/oneone/settings.json, not embedded in module/UI JSON.
  Defaults OFF/30s/no-log for missing or invalid settings. Save uses existing native
  fsync/atomic-rename writer, verifies the result, rejects stale drafts by fingerprint.
- Three controls: enable bot, boot wait 0..600s, logging. Enable/log changes wake the
  bot's existing inotify watcher; boot wait applies at next boot.
- Strict bounded schema, duplicate/unknown keys rejected, fixed settingsId and
  reader/writer paths. Only OneOne is registered; other modules need an explicit
  trusted settings backend, not arbitrary root commands from JSON.
- Quick install offers a selection of server-published modules, not automatic pair
  installation. Check publication again before download; validate all selected ZIPs
  before running root. No implicit choice, rollback or automatic reboot.
- catalog.json on main controls names/publication without rebuilding APK. This is
  discoverability control, NOT access control on public assets or older APKs.
- Module cards show only name, toggle and action icons. Remove version/author/
  description/pending-reboot notices and their unused notice calculations.
- Magisk uninstall button has only trash icon, confirmation retained. Reboot icon
  has a continuous lower ring. Capitalize words in Vietnamese Superuser empty state.

Experimental Kitsune-based fork; same signing key, credits/licenses preserved.
Root/Hide preset from v1.0.5 remains. No live root reinstall/reboot performed for
this UI update. JSON is presentation data, never a root script or filesystem path.
