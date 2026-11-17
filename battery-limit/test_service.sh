#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/battery" "$TMP/state"
SWITCH=$TMP/battery/battery_charging_enabled
CAPACITY=$TMP/battery/capacity
LIMIT=$TMP/state/limit

tick() {
    BATTERY_DIR="$TMP/battery" STATE_DIR="$TMP/state" sh "$ROOT/module/service.sh" --once
}
assert_switch() {
    actual=$(cat "$SWITCH")
    [ "$actual" = "$1" ] || { echo "expected $1, got $actual" >&2; exit 1; }
}

for limit in 60 70 80 85 90; do
    printf '%s\n' "$limit" > "$LIMIT"
    printf '%s\n' "$limit" > "$CAPACITY"
    printf '1\n' > "$SWITCH"
    tick
    assert_switch 0
    printf '%s\n' "$((limit - 1))" > "$CAPACITY"
    tick
    assert_switch 0
    printf '%s\n' "$((limit - 3))" > "$CAPACITY"
    tick
    assert_switch 1
done

printf '100\n' > "$LIMIT"
printf '100\n' > "$CAPACITY"
printf '0\n' > "$SWITCH"
tick
assert_switch 1

printf 'bad\n' > "$CAPACITY"
printf '0\n' > "$SWITCH"
if tick; then echo 'invalid capacity was accepted' >&2; exit 1; fi
assert_switch 0
echo 'battery charge-limit tests passed'
