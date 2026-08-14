#!/system/bin/sh

MODDIR=${0%/*}
IDS=

if [ -f "$MODDIR/applied-subids" ]; then
  IDS="$(tr '\n' ' ' < "$MODDIR/applied-subids")"
fi
QUERY_IDS="$(content query --uri content://telephony/siminfo --projection _id:sim_id 2>/dev/null |
  sed -n 's/.*_id=\([-0-9][0-9]*\).*sim_id=\([0-9][0-9]*\).*/\1/p' | tr '\n' ' ')"

for SID in $IDS $QUERY_IDS; do
  case "$SID" in ''|*[!0-9]*) continue ;; esac
  case " $CLEARED " in *" $SID "*) continue ;; esac
  service call carrier_config 2 i32 "$SID" i32 0 >/dev/null 2>&1 || true
  CLEARED="$CLEARED $SID"
done
exit 0
