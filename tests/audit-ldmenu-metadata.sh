#!/system/bin/sh
# Read only names/metadata of the exact game, never pipe/socket contents or keys.
set -eu
[ "$(id -u)" = 0 ]
pid=${1:?exact game pid}
case "$pid" in ''|*[!0-9]*) exit 2;; esac
[ "$(tr '\000' '\n' < /proc/$pid/cmdline | head -n 1)" = com.vng.playtogether ]
echo MODULE_MAPPING_NAMES
grep -E 'ldmenu|ktools|library_188|libLoaderZygisk|memfd:jit-cache' /proc/$pid/maps || true
echo MODULE_FD_NAMES
for fd in /proc/$pid/fd/*; do
 name=$(readlink "$fd") || continue
 case "$name" in *ldmenu*|*ktools*|*library_188*|*memfd:jit-cache*) printf '%s -> %s\n' "${fd##*/}" "$name";; esac
done
echo CACHE_PAYLOAD_NAMES
# Exact loader cache only; no general game/account directory scan.
if [ -d /data/data/com.vng.playtogether/cache/tmp/ktools_loader ]; then
 find /data/data/com.vng.playtogether/cache/tmp/ktools_loader -maxdepth 1 -type f -name 'library_*.so'
fi
