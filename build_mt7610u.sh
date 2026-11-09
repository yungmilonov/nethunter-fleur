#!/usr/bin/env bash
set -uo pipefail
TC=$GITHUB_WORKSPACE/toolchain/bin

git clone -q --depth=1 https://github.com/ulli-kroll/mt7610u.git
cd mt7610u

# --- ensure TP-Link Archer T2U Plus USB ID (2357:0120) ---
python3 - <<'PYEOF'
import re
p = 'common/rtusb_dev_id.c'
try:
    s = open(p).read()
except FileNotFoundError:
    import glob
    cand = glob.glob('**/rtusb_dev_id.c', recursive=True)
    if not cand:
        print('WARNING: rtusb_dev_id.c not found, skipping ID patch')
        raise SystemExit(0)
    p = cand[0]
    s = open(p).read()
if '0x0120' not in s:
    m = re.search(r'\{USB_DEVICE\(', s)
    if m:
        s = s[:m.start()] + '{USB_DEVICE(0x2357,0x0120)}, /* TP-Link Archer T2U Plus */\n\t' + s[m.start():]
        open(p, 'w').write(s)
        print('USB ID 2357:0120 added to', p)
    else:
        print('WARNING: no anchor for ID patch in', p)
else:
    print('USB ID 2357:0120 already present in', p)
PYEOF

# --- build (vendor-style driver: try known entry points) ---
set -o pipefail
if ( cd os/linux 2>/dev/null && make ARCH=arm64 CC=$TC/clang CROSS_COMPILE=/usr/bin/aarch64-linux-gnu- \
       KSRC=$GITHUB_WORKSPACE/kernel/out -j"$(nproc)" 2>&1 | tee $GITHUB_WORKSPACE/mt7610u.log ); then
  echo "built via os/linux"
else
  make ARCH=arm64 CC=$TC/clang CROSS_COMPILE=/usr/bin/aarch64-linux-gnu- \
    KSRC=$GITHUB_WORKSPACE/kernel/out -j"$(nproc)" 2>&1 | tee $GITHUB_WORKSPACE/mt7610u.log
fi
find . -name '*.ko' -print
