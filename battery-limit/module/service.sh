#!/system/bin/sh

MODDIR=${0%/*}
BATTERY_DIR=${BATTERY_DIR:-/sys/class/power_supply/battery}
USB_DIR=${USB_DIR:-/sys/class/power_supply/usb}
STATE_DIR=${STATE_DIR:-/data/adb/3917jr_battery_limit}
CHARGE=$BATTERY_DIR/battery_charging_enabled
INPUT=$BATTERY_DIR/input_suspend
CAPACITY=$BATTERY_DIR/capacity
PRESENT=$USB_DIR/present

mkdir -p "$STATE_DIR" || exit 1
chmod 700 "$STATE_DIR"
[ -f "$STATE_DIR/limit" ] || printf '100\n' > "$STATE_DIR/limit"
[ -f "$STATE_DIR/cycle.conf" ] || printf '0 30\n' > "$STATE_DIR/cycle.conf"
[ -f "$STATE_DIR/phase" ] || printf 'idle\n' > "$STATE_DIR/phase"
[ -f "$STATE_DIR/next_due" ] || printf '0\n' > "$STATE_DIR/next_due"
chmod 600 "$STATE_DIR/limit" "$STATE_DIR/cycle.conf" "$STATE_DIR/phase" "$STATE_DIR/next_due"

write_state() {
    [ "$(cat "$STATE_DIR/$1" 2>/dev/null)" = "$2" ] && return 0
    printf '%s\n' "$2" > "$STATE_DIR/$1.$$" &&
        chmod 600 "$STATE_DIR/$1.$$" &&
        mv -f "$STATE_DIR/$1.$$" "$STATE_DIR/$1"
}

set_switch() {
    [ "$(cat "$1" 2>/dev/null)" = "$2" ] && return 0
    printf '%s\n' "$2" > "$1" || return 1
    [ "$(cat "$1" 2>/dev/null)" = "$2" ]
}

normal_limit() {
    set_switch "$INPUT" 0 || return 1
    if [ "$limit" -eq 100 ] || [ "$level" -le $((limit - 3)) ]; then
        set_switch "$CHARGE" 1
    elif [ "$level" -ge "$limit" ]; then
        set_switch "$CHARGE" 0
    fi
}

abort_cycle() {
    write_state phase idle
    write_state next_due "$((now + 86400))"
    write_state last_result interrupted
    rm -f "$STATE_DIR/start_request"
    set_switch "$INPUT" 0
    normal_limit
}

complete_cycle() {
    write_state phase idle
    write_state last_completed "$now"
    write_state last_result completed
    write_state next_due "$((now + days * 86400))"
    normal_limit
}

tick() {
    [ -r "$CHARGE" ] && [ -w "$CHARGE" ] &&
        [ -r "$INPUT" ] && [ -w "$INPUT" ] &&
        [ -r "$CAPACITY" ] && [ -r "$PRESENT" ] || return 1

    limit=$(cat "$STATE_DIR/limit" 2>/dev/null)
    case "$limit" in 60|70|80|85|90|100) ;; *) limit=100 ;; esac
    level=$(cat "$CAPACITY" 2>/dev/null)
    case "$level" in ''|*[!0-9]*) set_switch "$INPUT" 0; set_switch "$CHARGE" 1; return 1 ;; esac
    [ "$level" -le 100 ] || { set_switch "$INPUT" 0; set_switch "$CHARGE" 1; return 1; }

    read enabled days < "$STATE_DIR/cycle.conf"
    case "$enabled" in 0|1) ;; *) enabled=0 ;; esac
    case "$days" in ''|*[!0-9]*) days=30 ;; esac
    [ "$days" -ge 7 ] && [ "$days" -le 365 ] || days=30
    config="$enabled $days"
    phase=$(cat "$STATE_DIR/phase" 2>/dev/null)
    case "$phase" in idle|draining|charging|returning) ;; *) phase=idle; write_state phase idle ;; esac
    due=$(cat "$STATE_DIR/next_due" 2>/dev/null)
    case "$due" in ''|*[!0-9]*) due=0 ;; esac
    now=${NOW_EPOCH:-$(date +%s)}
    case "$now" in ''|*[!0-9]*) set_switch "$INPUT" 0; set_switch "$CHARGE" 1; return 1 ;; esac
    [ "$now" -ge 1600000000 ] || { set_switch "$INPUT" 0; set_switch "$CHARGE" 1; return 1; }
    present=$(cat "$PRESENT" 2>/dev/null)

    observed=$(cat "$STATE_DIR/cycle_observed" 2>/dev/null)
    if [ "$observed" != "$config" ]; then
        write_state cycle_observed "$config"
        if [ "$enabled" -eq 1 ] && [ "$phase" = idle ]; then
            due=$((now + days * 86400))
            write_state next_due "$due"
        fi
    fi

    if [ "$enabled" -eq 0 ]; then
        [ "$phase" = idle ] || write_state phase idle
        write_state next_due 0
        rm -f "$STATE_DIR/start_request"
        normal_limit
        return $?
    fi

    if [ "$phase" != idle ] && [ "$present" != 1 ]; then
        abort_cycle
        return $?
    fi

    if [ "$phase" = idle ]; then
        if [ "$present" = 1 ] &&
            { [ -f "$STATE_DIR/start_request" ] || { [ "$due" -gt 0 ] && [ "$now" -ge "$due" ]; }; }; then
            rm -f "$STATE_DIR/start_request"
            phase=draining
            write_state phase "$phase"
        else
            normal_limit
            return $?
        fi
    fi

    case "$phase" in
        draining)
            if [ "$level" -le 10 ]; then
                write_state phase charging
                set_switch "$INPUT" 0 && set_switch "$CHARGE" 1
            else
                set_switch "$CHARGE" 0 && set_switch "$INPUT" 1 || abort_cycle
            fi
            ;;
        charging)
            set_switch "$INPUT" 0 && set_switch "$CHARGE" 1 || { abort_cycle; return 1; }
            [ "$level" -lt 100 ] || write_state phase returning
            ;;
        returning)
            if [ "$level" -le "$limit" ]; then
                complete_cycle
            else
                set_switch "$CHARGE" 0 && set_switch "$INPUT" 1 || abort_cycle
            fi
            ;;
    esac
}

if [ "$1" = --once ]; then
    tick
    exit $?
fi

printf '%s\n' "$$" > "$STATE_DIR/service.pid"
sh "$MODDIR/watchdog.sh" &
WATCHDOG_PID=$!
trap 'kill "$WATCHDOG_PID" 2>/dev/null; printf "0\n" > "$INPUT" 2>/dev/null; printf "1\n" > "$CHARGE" 2>/dev/null; rm -f "$STATE_DIR/service.pid"' EXIT
while [ -d "$MODDIR" ] && [ ! -e "$MODDIR/disable" ] && [ ! -e "$MODDIR/remove" ]; do
    tick
    sleep 10
done
