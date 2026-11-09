# nethunter-fleur

Kali NetHunter kernel for **POCO M4 Pro 4G (fleur)** — MediaTek Helio G96 (MT6781), kernel 4.14, built from `MiCode/Xiaomi_Kernel_OpenSource` branch `fleur-s-oss`.

Built on GitHub Actions. Go to **Actions → Build NetHunter kernel (fleur)** → open the latest run → download artifact `nethunter-fleur`.

## Artifacts

| File | What it is |
|---|---|
| `AnyKernel3-nethunter-fleur.zip` | Kernel itself. Flash via Kernel Flasher app / TWRP. Replaces only the kernel, ramdisk (Magisk) untouched. |
| `nethunter-fleur-modules-firmware.zip` | Magisk module: external Wi-Fi modules (88XXAU, MT7610U) + firmware files. Install via Magisk app → Modules → Install from storage. |
| `fleur-nethunter.config` | The exact kernel config used. |
| `*.log` | Build logs for debugging. |

## What's enabled

- **USB gadget attacks**: HID keyboard, mass storage (DriveDroid), functionfs (USB Arsenal), MIDI, accessory, RNDIS/NCM
- **Wi-Fi monitor mode**: rt2800usb (RT3070/RT5370 — TL-WN727N), mt7601u, ath9k_htc, carl9170, zd1211rw, rtl8xxxu (in-tree) + external 88XXAU (RTL8812AU) and MT7610U (Archer T2U Plus, USB ID 2357:0120 patched in)
- **USB host**: serial (FTDI/CP210x/CH341/PL2303/Option/Sierra), LTE modems (QMI/MBIM/NCM/RNDIS), USB-Ethernet, USB audio, webcams, BT dongles, UAS
- `USB_ANNOUNCE_NEW_DEVICES` — any unknown device shows its VID:PID in dmesg

## Rollback

Boot partition backup (`boot_backup.img`) is taken before flashing. To revert:

```
fastboot flash boot boot_backup.img
```

Phone returns to exact stock kernel (Magisk stays — it lives in the ramdisk which we never touch).
