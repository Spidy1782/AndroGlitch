#!/system/bin/sh
# Grant Magisk superuser to the adb shell user (uid 2000) headlessly so
# `adb shell su -c ...` works without tapping an on-device prompt.
# policy=2 (allow); idempotent (REPLACE).
magisk --sqlite "REPLACE INTO policies (uid,policy,until,logging,notification) VALUES(2000,2,0,1,1)"
echo "--- policies ---"
magisk --sqlite "SELECT * FROM policies"
