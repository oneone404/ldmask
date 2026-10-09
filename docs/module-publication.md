# Publish/select modules

Edit catalog.json on main:

    { "id": "oneone", "name": "OneOne", "published": true }

published=false hides that module from this app's quick-install picker and prevents
new quick installs via this feature. Set true to show again. Changes need a Git
commit/push, not an APK/release rebuild. GitHub/CDN propagation may take time.
Missing/invalid/offline catalog fails closed; the app never defaults to downloading
everything. Picker selection begins empty. Server state is checked again at install,
so a module hidden between selection and install is rejected without root execution.

modules.json is release-specific integrity metadata: ID, asset, versionCode, size,
SHA256. Schema2 permits a subset/empty set; schema1 remains readable. Only the two
fixed supported IDs oneone/ktools_zygisk and fixed asset names are accepted.
New IDs require a host allowlist update, not arbitrary server-supplied shell/path.
All selected ZIPs must pass size/hash/identity/path validation before any root install.

For a new release, stage the APK/available ZIPs/integrity metadata as a draft,
verify uploaded hashes, then publish latest. Do not silently replace published ZIPs.
Hidden modules may be omitted entirely from the next manifest/release; the reader
also ignores an unpublished metadata row whose ZIP asset is absent.

IMPORTANT: catalog is not authorization. Public ZIP links remain downloadable;
older LDMask versions do not honor catalog, nor do other download clients. For
true restriction, do not publish the binary (including removing old public assets)
or use an authenticated server. This public GitHub-only app contains no download
passwords/tokens/admin credential, and cannot make already-public binaries private.
