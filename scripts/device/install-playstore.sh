#!/system/bin/sh
# Install the Play Store (Phonesky) as a PRIVILEGED PRODUCT system app and make
# it stay working across its own auto-updates. Run as root after `adb remount`.
# Inputs (pushed to /data/local/tmp): Phonesky.apk, privapp-permissions-vending.xml
set -e
APK=/data/local/tmp/Phonesky.apk
XML=/data/local/tmp/privapp-permissions-vending.xml
[ -f "$APK" ] || { echo "missing $APK"; exit 1; }

# 1. privapp perms enforce -> log: the auto-updating Play Store's privileged
#    permission set changes; 'log' grants instead of denying (avoids bootloop).
sed -i 's/^ro\.control_privapp_permissions=enforce/ro.control_privapp_permissions=log/' /vendor/build.prop || true

# 2. install to /product/priv-app (matches the package's PRODUCT record + the
#    GMS layout) so it keeps the PRIVILEGED flag (needed for MANAGE_USERS).
mkdir -p /product/priv-app/Phonesky
cp "$APK" /product/priv-app/Phonesky/Phonesky.apk
chmod 755 /product/priv-app/Phonesky
chmod 644 /product/priv-app/Phonesky/Phonesky.apk
chcon u:object_r:system_file:s0 /product/priv-app/Phonesky/Phonesky.apk

mkdir -p /product/etc/permissions
cp "$XML" /product/etc/permissions/privapp-permissions-vending.xml
chmod 644 /product/etc/permissions/privapp-permissions-vending.xml
chcon u:object_r:system_file:s0 /product/etc/permissions/privapp-permissions-vending.xml

# 3. remove ambiguous copies:
#    - /system/priv-app/Phonesky  (partition-mismatched copy)
#    - /product/app/LicenseChecker (the FAKE non-privileged com.android.vending
#      stub whose record /data updates inherit -> MANAGE_USERS crash)
rm -rf /system/priv-app/Phonesky
rm -rf /product/app/LicenseChecker

# 4. drop any /data update that inherited the non-privileged record
pm uninstall-system-updates com.android.vending 2>/dev/null || true

echo "=== /product/priv-app/Phonesky ==="
ls -lZ /product/priv-app/Phonesky/
echo "=== stub check ==="
ls /product/app/ | grep -i license || echo "  (LicenseChecker gone)"
grep control_privapp_permissions /vendor/build.prop
echo done
