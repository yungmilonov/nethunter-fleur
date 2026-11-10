# nethunter-fleur

NetHunter driver modules for **POCO M4 Pro 4G / Redmi Note 11S 4G (fleur)** running **LineageOS 22.1** from [mt6781-devs](https://github.com/mt6781-devs/releases/tag/lineage-22).

Built with the **exact ROM toolchain** (Android clang r530567, `LLD 19`) against the exact ROM kernel source commit (`5bf0cec8e008`, kernel `4.19.325-g5bf0cec8e008`) using the device's live kernel config (`/proc/config.gz`, saved in this repo as `rom_kernel_config`).

> The ROM kernel is built with `CONFIG_LTO_CLANG=y` — modules built with any other toolchain/config (proton clang, different clang version, no-LTO) oops the kernel on insmod, even with matching vermagic and CRC bypass. Only this exact toolchain+config combination produces ABI-compatible modules. Do NOT flash kernel images from old CI runs — they were for HyperOS experiments and are known-bad.

## Artifacts (Actions → latest run → `nethunter-fleur`)

| File | What it is |
|---|---|
| `nethunter-fleur-modules-firmware.zip` | **Magisk module**: 37 modules (Wi-Fi monitor, LTE, serial, USB-LAN, BT, audio) + firmware. Install via Magisk → Modules → Install from storage. Reboot. |
| `Module.symvers` | Symbol CRC table of this build — needed to build additional modules against the same kernel. |
| `fleur-nethunter.config` | Exact kernel config used (ROM live config + NetHunter fragment). |
| `*.log` | Build logs. |

## Covering your adapters

| Adapter | Chip | Driver |
|---|---|---|
| TP-Link Archer T2U Plus | Realtek **RTL8811AU** (2357:011e), *not* MT7610U | `88XXau.ko` (aircrack-ng) — monitor mode + injection |
| TP-Link TL-WN727N | Ralink RT3070/RT5370 (or MT7601 on some revs) | `rt2800usb.ko` + `mac80211.ko` (shipped) / `mt7601u.ko` |
| LTE dongles | QMI/MBIM | `qmi_wwan.ko`, `option.ko`, `cdc_*` |
| Serial/Arduino/GPS | FTDI/CP210x/CH341/PL2303 | `ftdi_sio.ko` etc. |
| USB LAN / BT dongles / webcams / audio | — | full set shipped |

Adapters plug in via a USB-C OTG adapter. Check load: `lsmod` (via root shell), plug in, `dmesg | tail`.

## Install / update the drivers

1. Download the artifact, push `nethunter-fleur-modules-firmware.zip` to the phone.
2. Magisk → Modules → Install from storage → select the zip → reboot.
3. Modules load at boot via `service.sh` (two-pass insmod with 20s timeout each).
4. To disable (e.g. if a module misbehaves): create `/data/adb/modules/nethunter_fleur_max/disable` and reboot.

## Rebuilding after kernel updates

If LineageOS ROM updates its kernel (new commit hash in `uname -r`):
1. Update the commit in `.github/workflows/build.yml` (`git fetch origin <new-sha>`).
2. Replace `rom_kernel_config` with the new `/proc/config.gz` dump.
3. Keep `LOCALVERSION="-g<new-full-hash>"` matching `uname -r` exactly.
4. Push → CI builds → install the new zip.

## Repo state notes

- `nethunter.config` — the fragment layered on top of the ROM's live config (MAC80211=m — the ROM kernel lacks it; drivers zoo; MODVERSIONS=y — required by ROM kernel vermagic).
- `build_mt7610u.sh` was removed: Archer T2U Plus is Realtek RTL8811AU, not MT7610U — covered by 88XXau.
- The non-LTO kernel images from earlier CI runs (HyperOS era + Lineage attempt) are known-bad: the Lineage ROM kernel uses ClangLTO, and the old images target HyperOS — do not flash them.
