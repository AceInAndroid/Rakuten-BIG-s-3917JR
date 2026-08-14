#!/system/bin/sh

MODDIR=${0%/*}
LOG="$MODDIR/apn-unlock.log"
APPLIED="$MODDIR/applied-subids"

log_msg() {
  NOW="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
  echo "$NOW $*" >> "$LOG"
}

trim_log() {
  SIZE="$(wc -c < "$LOG" 2>/dev/null)"
  case "$SIZE" in ''|*[!0-9]*) SIZE=0 ;; esac
  if [ "$SIZE" -gt 65536 ]; then
    tail -c 32768 "$LOG" > "$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG"
  fi
}

service_ready() {
  service check carrier_config 2>/dev/null | grep -q 'found'
}

active_subids() {
  content query --uri content://telephony/siminfo --projection _id:sim_id 2>/dev/null |
    sed -n 's/.*_id=\([-0-9][0-9]*\).*sim_id=\([-0-9][0-9]*\).*/\1 \2/p' |
    while read SID SLOT; do
      case "$SID" in ''|*[!0-9]*) continue ;; esac
      case "$SLOT" in ''|*[!0-9]*) continue ;; esac
      echo "$SID"
    done
}

apply_all() {
  IDS="$1"
  FAILED=0
  : > "$APPLIED.tmp"
  for SID in $IDS; do
    OUT="$MODDIR/service-call-$SID.tmp"
    service call carrier_config 2 i32 "$SID" i32 1 i32 96 i32 1279544898 \
      i32 1 s16 read_only_apn_types_string_array i32 14 i32 1 s16 dun > "$OUT" 2>&1
    RC=$?
    cat "$OUT" >> "$LOG"
    if [ "$RC" -eq 0 ] && grep -q 'Result: Parcel' "$OUT" &&
       ! grep -Eqi 'Exception|Error' "$OUT"; then
      echo "$SID" >> "$APPLIED.tmp"
      log_msg "Binder transaction succeeded for subId=$SID"
    else
      log_msg "Binder transaction failed for subId=$SID (exit=$RC)"
      FAILED=1
    fi
    rm -f "$OUT"
  done

  DUMP="$MODDIR/carrier-config-dump.tmp"
  dumpsys carrier_config > "$DUMP" 2>&1
  cat "$DUMP" >> "$LOG"
  if [ "$FAILED" -eq 0 ] &&
     grep -Eq 'read_only_apn_types_string_array[[:space:]]*=[[:space:]]*\[dun\]' "$DUMP" &&
     ! grep -Eqi 'Exception|Error' "$DUMP"; then
    mv -f "$APPLIED.tmp" "$APPLIED"
    log_msg "global dumpsys verification succeeded: override=[dun]"
    rm -f "$DUMP"
    return 0
  fi

  log_msg "global dumpsys verification failed"
  rm -f "$DUMP" "$APPLIED.tmp"
  return 1
}

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 5; done
while ! service_ready; do sleep 5; done
log_msg "monitor started"

LAST_STATE=
while true; do
  if service_ready; then
    PHONE_PID="$(pidof com.android.phone 2>/dev/null)"
    IDS="$(active_subids | tr '\n' ' ')"
    STATE="up|$PHONE_PID|$IDS"
    if [ -n "$IDS" ] && [ "$STATE" != "$LAST_STATE" ]; then
      log_msg "state changed: $STATE"
      log_msg "applying for subIds: $IDS (phone pid: ${PHONE_PID:-unknown})"
      if ! apply_all "$IDS"; then
        STATE=retry
      fi
    fi
  else
    STATE=down
    [ "$STATE" = "$LAST_STATE" ] || log_msg "state changed: carrier_config unavailable"
  fi
  LAST_STATE="$STATE"
  trim_log
  sleep 20
done
