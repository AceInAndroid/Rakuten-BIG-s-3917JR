#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/battery" "$TMP/usb" "$TMP/state"
CHARGE=$TMP/battery/battery_charging_enabled
INPUT=$TMP/battery/input_suspend
CAPACITY=$TMP/battery/capacity
PRESENT=$TMP/usb/present
STATE=$TMP/state
NOW=1800000000

tick() {
    BATTERY_DIR="$TMP/battery" USB_DIR="$TMP/usb" STATE_DIR="$STATE" NOW_EPOCH="$NOW" \
        sh "$ROOT/module/service.sh" --once
}
control() {
    STATE_DIR="$STATE" USB_DIR="$TMP/usb" sh "$ROOT/module/control.sh" "$@"
}
watchdog_once() {
    BATTERY_DIR="$TMP/battery" STATE_DIR="$STATE" sh "$ROOT/module/watchdog.sh" --once
}
assert_file() {
    actual=$(cat "$1")
    [ "$actual" = "$2" ] || { echo "$1: expected $2, got $actual" >&2; exit 1; }
}

printf '100\n' > "$CAPACITY"
printf '1\n' > "$PRESENT"
printf '1\n' > "$CHARGE"
printf '0\n' > "$INPUT"
tick
assert_file "$STATE/limit" 100
assert_file "$STATE/cycle.conf" '0 30'

for limit in 60 70 80 85 90; do
    control set-limit "$limit"
    printf '%s\n' "$limit" > "$CAPACITY"
    tick
    assert_file "$CHARGE" 0
    printf '%s\n' "$((limit - 1))" > "$CAPACITY"
    tick
    assert_file "$CHARGE" 0
    printf '%s\n' "$((limit - 3))" > "$CAPACITY"
    tick
    assert_file "$CHARGE" 1
done
control set-limit 80
control set-cycle 1 30
tick
assert_file "$STATE/next_due" "$((NOW + 30 * 86400))"
tick
assert_file "$STATE/next_due" "$((NOW + 30 * 86400))"

printf '%s\n' "$((NOW - 1))" > "$STATE/next_due"
printf '85\n' > "$CAPACITY"
tick
assert_file "$STATE/phase" draining
assert_file "$INPUT" 1
assert_file "$CHARGE" 0

printf '10\n' > "$CAPACITY"
tick
assert_file "$STATE/phase" charging
assert_file "$INPUT" 0
assert_file "$CHARGE" 1
printf '80\n' > "$CAPACITY"
tick
assert_file "$CHARGE" 1
printf '100\n' > "$CAPACITY"
tick
assert_file "$STATE/phase" returning
tick
assert_file "$INPUT" 1
assert_file "$CHARGE" 0
printf '80\n' > "$CAPACITY"
tick
assert_file "$STATE/phase" idle
assert_file "$INPUT" 0
assert_file "$CHARGE" 0
assert_file "$STATE/next_due" "$((NOW + 30 * 86400))"
assert_file "$STATE/last_completed" "$NOW"

printf '%s\n' "$((NOW - 1))" > "$STATE/next_due"
printf '60\n' > "$CAPACITY"
tick
assert_file "$STATE/phase" draining
printf '0\n' > "$PRESENT"
tick
assert_file "$STATE/phase" idle
assert_file "$INPUT" 0
assert_file "$STATE/next_due" "$((NOW + 86400))"
printf '1\n' > "$PRESENT"

control set-cycle 0 30
tick
assert_file "$STATE/next_due" 0
if control start-now; then echo 'disabled cycle started' >&2; exit 1; fi
if control set-cycle 1 1; then echo 'short period accepted' >&2; exit 1; fi
control set-cycle 1 14
tick
assert_file "$STATE/next_due" "$((NOW + 14 * 86400))"
control start-now
tick
assert_file "$STATE/phase" draining

control set-cycle 0 14
tick
assert_file "$STATE/phase" idle
assert_file "$INPUT" 0
control set-limit 100
tick
assert_file "$CHARGE" 1

printf 'bad\n' > "$CAPACITY"
printf '1\n' > "$INPUT"
if tick; then echo 'invalid capacity was accepted' >&2; exit 1; fi
assert_file "$INPUT" 0
assert_file "$CHARGE" 1

printf '%s\n' "$$" > "$STATE/service.pid"
printf '10\n' > "$CAPACITY"
printf '1\n' > "$INPUT"
printf '0\n' > "$CHARGE"
watchdog_once
assert_file "$INPUT" 0
assert_file "$CHARGE" 1

printf '999999\n' > "$STATE/service.pid"
printf '20\n' > "$CAPACITY"
printf '1\n' > "$INPUT"
printf '0\n' > "$CHARGE"
if watchdog_once; then echo 'dead service was not detected' >&2; exit 1; fi
assert_file "$INPUT" 0
assert_file "$CHARGE" 1
echo 'battery charge-limit and maintenance-cycle tests passed'
