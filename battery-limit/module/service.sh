#!/system/bin/sh

MODDIR=${0%/*}
BATTERY_DIR=${BATTERY_DIR:-/sys/class/power_supply/battery}
STATE_DIR=${STATE_DIR:-/data/adb/3917jr_battery_limit}
SWITCH=$BATTERY_DIR/battery_charging_enabled
CAPACITY=$BATTERY_DIR/capacity
LIMIT_FILE=$STATE_DIR/limit

mkdir -p "$STATE_DIR" || exit 1
chmod 700 "$STATE_DIR"
[ -f "$LIMIT_FILE" ] || printf '100\n' > "$LIMIT_FILE"
chmod 600 "$LIMIT_FILE"

tick() {
    [ -r "$SWITCH" ] && [ -w "$SWITCH" ] && [ -r "$CAPACITY" ] || return 1
    limit=$(cat "$LIMIT_FILE" 2>/dev/null)
    case "$limit" in
        60|70|80|85|90|100) ;;
        *) limit=100 ;;
    esac
    level=$(cat "$CAPACITY" 2>/dev/null)
    case "$level" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$level" -le 100 ] || return 1
    current=$(cat "$SWITCH" 2>/dev/null)
    desired=$current
    if [ "$limit" -eq 100 ] || [ "$level" -le $((limit - 3)) ]; then
        desired=1
    elif [ "$level" -ge "$limit" ]; then
        desired=0
    fi
    if [ "$desired" != "$current" ]; then
        printf '%s\n' "$desired" > "$SWITCH" || return 1
    fi
    return 0
}

if [ "$1" = --once ]; then
    tick
    exit $?
fi

printf '%s\n' "$$" > "$STATE_DIR/service.pid"
trap 'printf "1\n" > "$SWITCH" 2>/dev/null; rm -f "$STATE_DIR/service.pid"' EXIT
while [ -d "$MODDIR" ] && [ ! -e "$MODDIR/disable" ] && [ ! -e "$MODDIR/remove" ]; do
    tick
    sleep 10
done
