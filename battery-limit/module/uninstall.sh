#!/system/bin/sh

STATE_DIR=/data/adb/3917jr_battery_limit
SWITCH=/sys/class/power_supply/battery/battery_charging_enabled
if [ -f "$STATE_DIR/service.pid" ]; then
    pid=$(cat "$STATE_DIR/service.pid")
    case "$pid" in
        ''|*[!0-9]*) ;;
        *) kill "$pid" 2>/dev/null ;;
    esac
fi
printf '1\n' > "$SWITCH" 2>/dev/null
rm -rf "$STATE_DIR"
