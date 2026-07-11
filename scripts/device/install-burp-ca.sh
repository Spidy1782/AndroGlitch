#!/system/bin/sh
# Place a PEM CA (already hashed as <subject_hash_old>.0 and pushed to
# /data/local/tmp) into the Android 12 system trust store with the correct
# permissions + SELinux label. Run as root after `adb remount`.
HASH="$1"
[ -n "$HASH" ] || { echo "usage: install-burp-ca.sh <hash>.0"; exit 1; }
SRC=/data/local/tmp/$HASH
DST=/system/etc/security/cacerts/$HASH
cp "$SRC" "$DST"
chmod 644 "$DST"
chown root:root "$DST" 2>/dev/null
chcon u:object_r:system_security_cacerts_file:s0 "$DST"
ls -lZ "$DST"
echo "system CA count: $(ls /system/etc/security/cacerts/ | wc -l)"
