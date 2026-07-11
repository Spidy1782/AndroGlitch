#!/system/bin/sh
# Install bootanimation.zip (pushed to /data/local/tmp) to both /product/media
# and /system/media. Android searches oem -> product -> system, so the stock
# Google-dots animation in /product/media must be overridden too.
# Run as root after `adb remount`.
SRC=/data/local/tmp/bootanimation.zip
[ -f "$SRC" ] || { echo "missing $SRC"; exit 1; }
for DIR in /product/media /system/media; do
  mkdir -p "$DIR"
  # back up the stock one once
  [ -f "$DIR/bootanimation.zip" ] && [ ! -f "$DIR/bootanimation.zip.stock" ] && \
    cp "$DIR/bootanimation.zip" "$DIR/bootanimation.zip.stock"
  cp "$SRC" "$DIR/bootanimation.zip"
  chmod 644 "$DIR/bootanimation.zip"
  chcon u:object_r:system_file:s0 "$DIR/bootanimation.zip" 2>/dev/null
  echo "installed -> $DIR/bootanimation.zip"
done
