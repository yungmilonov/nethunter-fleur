#!/usr/bin/env bash
set -euo pipefail
WS=$PWD
OUT=$WS/out
mkdir -p "$OUT"

# ---------- modules ----------
KO=$WS/ko; mkdir -p "$KO"
find "$WS/kernel/out" -name '*.ko' -exec cp {} "$KO/" \; 2>/dev/null || true
find "$WS/rtl8812au" -name '*.ko'  -exec cp {} "$KO/" \; 2>/dev/null || true
echo "=== built modules ==="
ls -la "$KO"

# ---------- firmware ----------
FW=$WS/firmware; mkdir -p "$FW"
FB="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain"
curl -fsSL -o "$FW/rt2870.bin"        "$FB/rt2870.bin"              || echo "skip rt2870.bin"
curl -fsSL -o "$FW/mt7601u.bin"       "$FB/mt7601u.bin"             || echo "skip mt7601u.bin"
curl -fsSL -o "$FW/htc_9271-1.4.0.fw" "$FB/htc_9271-1.4.0.fw"       || echo "skip htc_9271"
curl -fsSL -o "$FW/carl9170-1.fw"     "$FB/carl9170-1.fw"           || echo "skip carl9170"
curl -fsSL -o "$FW/rtl8188eufw.bin"   "$FB/rtlwifi/rtl8188eufw.bin" || echo "skip rtl8188eufw"
curl -fsSL -o "$FW/rtl8192cufw.bin"   "$FB/rtlwifi/rtl8192cufw.bin" || echo "skip rtl8192cufw"

# ---------- Magisk module ----------
rm -rf mm
mkdir -p mm/META-INF/com/google/android mm/system/lib/modules mm/system/etc/firmware
cp "$KO"/*.ko mm/system/lib/modules/ 2>/dev/null || true
cp "$FW"/* mm/system/etc/firmware/ 2>/dev/null || true

cat > mm/module.prop <<'EOF'
id=nethunter_fleur_max
name=NetHunter fleur drivers (ROM ABI match)
version=v2.0
versionCode=2
author=yungmilonov
description=Wi-Fi/USB/LTE/BT/serial modules built with Android clang r530567 against the running ROM kernel (commit 5bf0cec8e008). Two-pass insmod via service.sh.
EOF

cat > mm/service.sh <<'EOF'
#!/system/bin/sh
MODDIR=${0%/*}
(
  sleep 30
  for pass in 1 2; do
    for f in "$MODDIR"/system/lib/modules/*.ko; do
      [ -e "$f" ] || continue
      mod=$(basename "$f" .ko)
      grep -q "^$mod " /proc/modules && continue
      timeout 20 insmod "$f" 2>/dev/null || log -t NHMOD "insmod failed: $mod"
    done
  done
) &
EOF
chmod +x mm/service.sh

curl -fsSL -o mm/META-INF/com/google/android/update-binary \
  "https://raw.githubusercontent.com/topjohnwu/magisk-module-template/master/META-INF/com/google/android/update-binary" \
  || echo "WARNING: could not fetch Magisk update-binary stub"
echo "#MAGISK" > mm/META-INF/com/google/android/updater-script
( cd mm && zip -q -r9 "$OUT/nethunter-fleur-modules-firmware.zip" . )

# ---------- extras for debugging ----------
cp kernel/out/Module.symvers "$OUT/Module.symvers" 2>/dev/null || true
cp kernel/out/.config "$OUT/fleur-nethunter.config" 2>/dev/null || true
cp build.log "$OUT/" 2>/dev/null || true
cp rtl8812au.log "$OUT/" 2>/dev/null || true

echo "=== OUT ==="
ls -la "$OUT"
echo "PACKAGE DONE"
