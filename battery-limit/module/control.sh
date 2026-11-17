#!/system/bin/sh

STATE_DIR=${STATE_DIR:-/data/adb/3917jr_battery_limit}
USB_DIR=${USB_DIR:-/sys/class/power_supply/usb}
mkdir -p "$STATE_DIR" || exit 1
chmod 700 "$STATE_DIR"

save() {
    printf '%s\n' "$2" > "$STATE_DIR/$1.$$" &&
        chmod 600 "$STATE_DIR/$1.$$" &&
        mv -f "$STATE_DIR/$1.$$" "$STATE_DIR/$1"
}

case "$1" in
    set-limit)
        case "$2" in 60|70|80|85|90|100) save limit "$2" ;; *) exit 2 ;; esac
        ;;
    set-cycle)
        case "$2" in 0|1) ;; *) exit 2 ;; esac
        case "$3" in ''|*[!0-9]*) exit 2 ;; esac
        [ "$3" -ge 7 ] && [ "$3" -le 365 ] || exit 2
        save cycle.conf "$2 $3"
        ;;
    start-now)
        read enabled days < "$STATE_DIR/cycle.conf" || exit 2
        [ "$enabled" = 1 ] && [ "$(cat "$STATE_DIR/phase")" = idle ] &&
            [ "$(cat "$USB_DIR/present")" = 1 ] || exit 2
        save start_request "$(date +%s)"
        ;;
    status)
        read enabled days < "$STATE_DIR/cycle.conf" 2>/dev/null || { enabled=0; days=30; }
        printf 'limit=%s\nenabled=%s\ndays=%s\nphase=%s\nnext_due=%s\nlast_completed=%s\nlast_result=%s\n' \
            "$(cat "$STATE_DIR/limit" 2>/dev/null)" "$enabled" "$days" \
            "$(cat "$STATE_DIR/phase" 2>/dev/null)" \
            "$(cat "$STATE_DIR/next_due" 2>/dev/null)" \
            "$(cat "$STATE_DIR/last_completed" 2>/dev/null)" \
            "$(cat "$STATE_DIR/last_result" 2>/dev/null)"
        ;;
    *) exit 2 ;;
esac
