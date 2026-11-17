#!/system/bin/sh

MODDIR=${0%/*}
BATTERY_DIR=${BATTERY_DIR:-/sys/class/power_supply/battery}
STATE_DIR=${STATE_DIR:-/data/adb/3917jr_battery_limit}
INPUT=$BATTERY_DIR/input_suspend
CHARGE=$BATTERY_DIR/battery_charging_enabled
CAPACITY=$BATTERY_DIR/capacity

restore_input() {
    printf '0\n' > "$INPUT" 2>/dev/null
    printf '1\n' > "$CHARGE" 2>/dev/null
}

check() {
    pid=$(cat "$STATE_DIR/service.pid" 2>/dev/null)
    case "$pid" in ''|*[!0-9]*) restore_input; return 1 ;; esac
    kill -0 "$pid" 2>/dev/null || { restore_input; return 1; }
    if [ "$(cat "$INPUT" 2>/dev/null)" = 1 ]; then
        level=$(cat "$CAPACITY" 2>/dev/null)
        case "$level" in
            ''|*[!0-9]*) restore_input ;;
            *) [ "$level" -gt 10 ] || restore_input ;;
        esac
    fi
    return 0
}

if [ "$1" = --once ]; then
    check
    exit $?
fi

trap 'restore_input; exit 0' TERM INT
while [ -d "$MODDIR" ] && [ ! -e "$MODDIR/disable" ] && [ ! -e "$MODDIR/remove" ]; do
    check || exit 0
    sleep 5
done
restore_input
