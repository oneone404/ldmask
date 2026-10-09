#!/system/bin/sh
# Called only after successful, user-confirmed quick installation.
[ "$(id -u)" = 0 ] || exit 10
case "$KEEP_LDLOGIN:$KEEP_LDMENU" in 1:1|1:0|0:1) ;; *) exit 11 ;; esac
keep_module() {
    case "$1" in
        ldlogin) [ "$KEEP_LDLOGIN" = 1 ] ;;
        ldmenu) [ "$KEEP_LDMENU" = 1 ] ;;
        *) return 1 ;;
    esac
}
# Validate both roots and every candidate before writing flags anywhere.
for BASE in /data/adb/modules /data/adb/modules_update; do
    [ ! -L "$BASE" ] || exit 12
    [ ! -e "$BASE" ] || [ -d "$BASE" ] || exit 12
    [ -d "$BASE" ] || continue
    for DIR in "$BASE"/*; do
        [ -e "$DIR" ] || [ -L "$DIR" ] || continue
        NAME=${DIR##*/}
        keep_module "$NAME" && continue
        [ ! -L "$DIR" ] || exit 13
        [ -d "$DIR" ] || continue
        case "$NAME" in ''|*[!A-Za-z0-9_.-]*) exit 14 ;; esac
        for FLAG in disable remove; do
            [ ! -L "$DIR/$FLAG" ] || exit 15
            [ ! -e "$DIR/$FLAG" ] || [ -f "$DIR/$FLAG" ] || exit 15
        done
    done
done
for BASE in /data/adb/modules /data/adb/modules_update; do
    [ -d "$BASE" ] || continue
    for DIR in "$BASE"/*; do
        [ -d "$DIR" ] || continue
        NAME=${DIR##*/}
        keep_module "$NAME" && continue
        [ ! -L "$BASE" ] && [ ! -L "$DIR" ] && [ ! -L "$DIR/disable" ] && [ ! -L "$DIR/remove" ] || exit 16
        touch "$DIR/disable" "$DIR/remove" || exit 17
        printf '%s\n' "- Removal pending: $NAME"
    done
done
printf '%s\n' '- Unlisted modules retired; reboot LD to finish removal.'
