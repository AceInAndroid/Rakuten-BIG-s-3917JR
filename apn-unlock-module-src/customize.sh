#!/system/bin/sh

ui_print "- Installing runtime CarrierConfig APN unlock"
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
