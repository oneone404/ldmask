#!/system/bin/sh
set -u
[ "$(id -u)" = 0 ] || { echo '! Root required'; exit 1; }
# Mark both active and staged modules: prepare_modules replaces active folders
# with staged ones before reading the remove marker on the next boot.
# No recursive deletion, reboot or root removal from the UI action itself.
for BASE in /data/adb/modules /data/adb/modules_update; do
    [ ! -L "$BASE" ] || { echo '! Refusing symlink module root'; exit 1; }
    for DIR in "$BASE"/*; do
        [ ! -L "$DIR" ] || { echo '! Refusing symlink module folder'; exit 1; }
        [ ! -d "$DIR" ] || [ ! -L "$DIR/remove" ] || { echo '! Refusing symlink marker'; exit 1; }
    done
done
COUNT=0
for BASE in /data/adb/modules /data/adb/modules_update; do
    for DIR in "$BASE"/*; do
        [ -d "$DIR" ] || continue
        touch "$DIR/remove" && [ -f "$DIR/remove" ] || { echo "! Cannot mark: $DIR"; exit 1; }
        echo "- Removal pending: ${DIR##*/} (${BASE##*/})"
        COUNT=$((COUNT + 1))
    done
done
echo "- $COUNT module folders marked. Reboot LD to finish removal. Root preserved."
