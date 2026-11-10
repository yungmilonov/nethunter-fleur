#!/usr/bin/env bash
set -euo pipefail
WS=$PWD
BOOT=$WS/kernel/out/arch/arm64/boot
OUT=$WS/out
mkdir -p "$OUT"

# ---------- 1) kernel image ----------
# 4.19 fleur layout (per mt6781-devs prebuilts): kernel = Image.gz, dtb separate,
# dtbo is a separate partition (not touched). Keep stock ramdisk & dtbo.
KERNEL="$BOOT/Image.gz"
DTB=""
if [ ! -f "$KERNEL" ]; then
  # legacy fallback: appended-dtb layout
  if [ -f "$BOOT/Image.gz-dtb" ]; then KERNEL="$BOOT/Image.gz-dtb"; fi
fi
DTB=$(find "$BOOT/dts" -name '*.dtb' 2>/dev/null | grep -Ei 'fleur|6781' | head -n1 || true)
echo "KERNEL=$KERNEL"
echo "DTB=${DTB:-none}"

# ---------- 2) AnyKernel3 flashable zip ----------
rm -rf ak3
git clone -q --depth=1 https://github.com/osm0sis/AnyKernel3.git ak3
rm -rf ak3/.git
cp "$KERNEL" ak3/Image.gz
cat > ak3/anykernel.sh <<EOF
# NetHunter-Max kernel for POCO M4 Pro 4G (fleur) - 4.19
kernel.string=NetHunter-Max-fleur-4.19-$(date +%Y%m%d-%H%M)
do.modules=0
do.cleanup=0
do.dtbo=0

BLOCK=auto
is_slot_device=1
ramdisk_compression=auto

files() {
  Image.gz;
}
EOF
if [ -n "$DTB" ]; then
  cp "$DTB" ak3/dtb
  awk '{ if ($0=="  Image.gz;") print "  Image.gz \\\n  dtb;"; else print }' ak3/anykernel.sh > ak3/anykernel.sh.tmp
  mv ak3/anykernel.sh.tmp ak3/anykernel.sh
fi
( cd ak3 && zip -q -r9 "$OUT/AnyKernel3-nethunter-fleur.zip" . )
echo "AnyKernel3 zip done"

# ---------- 3) firmware blobs ----------
FW=$WS/firmware; mkdir -p "$FW"
FB="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain"
curl -fsSL -o "$FW/rt2870.bin"        "$FB/rt2870.bin"                 || echo "skip rt2870.bin"
curl -fsSL -o "$FW/mt7601u.bin"       "$FB/mt7601u.bin"                || echo "skip mt7601u.bin"
curl -fsSL -o "$FW/htc_9271-1.4.0.fw" "$FB/htc_9271-1.4.0.fw"          || echo "skip htc_9271"
curl -fsSL -o "$FW/carl9170-1.fw"     "$FB/carl9170-1.fw"              || echo "skip carl9170"
curl -fsSL -o "$FW/rtl8188eufw.bin"   "$FB/rtlwifi/rtl8188eufw.bin"    || echo "skip rtl8188eufw"
curl -fsSL -o "$FW/rtl8192cufw.bin"   "$FB/rtlwifi/rtl8192cufw.bin"    || echo "skip rtl8192cufw"

# ---------- 4) Magisk module (modules + firmware) ----------
KO=$WS/ko; mkdir -p "$KO"
# external drivers
find "$WS/rtl8812au" -name '*.ko' -exec cp {} "$KO/" \; 2>/dev/null || true
find "$WS/mt7610u"   -name '*.ko' -exec cp {} "$KO/" \; 2>/dev/null || true
# ALL in-tree modules built with the kernel (rt2800usb, mt7601u, ath9k_htc, carl9170,
# zd1211rw, rtl8xxxu, UAS, usbnet stack, btusb, snd_usb_audio, ...)
find "$WS/kernel/out" -name '*.ko' -exec cp {} "$KO/" \; 2>/dev/null || true
ls -la "$KO" || true

rm -rf mm
mkdir -p mm/META-INF/com/google/android mm/system/lib/modules mm/system/etc/firmware
cp "$KO"/*.ko mm/system/lib/modules/ 2>/dev/null || true
cp "$FW"/* mm/system/etc/firmware/ 2>/dev/null || true

cat > mm/module.prop <<'EOF'
id=nethunter_fleur_max
name=NetHunter fleur modules and firmware
version=v1.0
versionCode=1
author=yungmilonov
description=External Wi-Fi/USB modules (88XXAU, MT7610U) and firmware for POCO M4 Pro 4G (fleur). Modules load at boot via service.sh.
EOF

cat > mm/service.sh <<'EOF'
#!/system/bin/sh
MODDIR=${0%/*}
(
  sleep 30
  # two passes: second loads modules whose dependencies appeared in the first
  for pass in 1 2; do
    for f in "$MODDIR"/system/lib/modules/*.ko; do
      [ -e "$f" ] || continue
      mod=$(basename "$f" .ko)
      grep -q "^$mod " /proc/modules && continue
      insmod "$f" 2>/dev/null || log -t NHMOD "insmod failed: $mod"
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
echo "Magisk module zip done"

# ---------- 5) extras for debugging ----------
cp kernel/out/.config "$OUT/fleur-nethunter.config" 2>/dev/null || true
cp build.log "$OUT/" 2>/dev/null || true
cp rtl8812au.log "$OUT/" 2>/dev/null || true
cp mt7610u.log "$OUT/" 2>/dev/null || true

echo "=== OUT ==="
ls -la "$OUT"
echo "PACKAGE DONE"
