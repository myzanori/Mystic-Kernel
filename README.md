# Mystic Universal Kernel for SM8250 (OnePlus 9R & 8T)

**Author:** myzanori  
**Kernel Base:** Linux 4.19.325 (CAF sm8250 / Kona)  
**Supported Devices:** OnePlus 9R (`lemonades` / `LE2101`), OnePlus 8T (`kebab` / `KB2001`), OnePlus 8 / 8 Pro (`instantnoodle` / `instantnoodlep`)  
**Tested ROMs:** OxygenOS 14 (`LE2101_14.0.0.2401(EX01)`), ColorOS 14/15/16 ports, AOSP/Custom ROMs  
**Root & Stealth:** ReSukiSU + SUSFS v2.3.0 (all 9 features enabled)

---

## Architecture & Engineering Highlights

### 1. Driver Architecture: Built-in Core + Modular WLAN
- **Preserved `CONFIG_MODVERSIONS=y`**: Prevents rogue out-of-tree vendor modules (built for older 4.19.157 stock kernels) from loading with mismatched struct offsets, which prevents spinning boot logo hangs.
- **Built-in Subsystems**: Audio (`adsp`, `q6_dlkm`), camera, sensors, and modem drivers are built directly into the kernel (`=y`), ensuring instant probe and zero ABI mismatch across different ROM vendor partitions.
- **Modular WLAN (`qcacld-3.0`)**: Compiled as a standalone module against the exact 4.19.325 kernel headers and loaded at boot via KernelSU helper module (`/data/adb/modules/mystic_wlan/`), avoiding early `cnss` firmware timeout before `/vendor` is mounted.

### 2. Camera PM8008 Driver Overflow Fix
- **Root Cause**: The device tree defines PM8008 regulators with 16-bit register addresses (`reg = <0x4000>`). The stock CAF driver called `of_property_read_u32` (requiring $\ge 4$ bytes), returning `-EOVERFLOW` (-75) and failing the probe of all 7 camera power regulators.
- **Resolution**: Implemented `of_property_read_u16` with a graceful `u32` fallback in `drivers/regulator/qcom_pm8008-regulator.c`.
- **Initialization Order**: Unified `pm8008_chip_driver` and `pm8008_regulator_driver` under `subsys_initcall` to guarantee that all camera power rails are active before camera sensor probes occur.
- **Result**: All 8 camera devices (IMX586 48MP main, IMX481 ultra-wide, IMX471 selfie, GC5035 macro, monochrome sensor) and triple-LED flashlight/torch function reliably.

### 3. Jitter, Schedutil & Storage Tuning
- **Schedutil Frequency Transition Tuning**:
  - Little Cores (0–3): `up_rate_limit_us=500`, `down_rate_limit_us=2000`
  - Big Cores (4–6): `up_rate_limit_us=500`, `down_rate_limit_us=2000`
  - Prime Core (7): `up_rate_limit_us=500`, `down_rate_limit_us=4000`
  - *Prevents rapid frequency ping-ponging, eliminating micro-stutters during UI scrolling while retaining instant ramp-up responsiveness.*
- **UFS Latency & Throughput Optimizations**:
  - `nr_requests=128`, `read_ahead_kb=512`
  - Disabled entropy overhead on storage devices (`add_random=0`) and I/O accounting overhead (`iostats=0`).
- **Automated Service**: Integrated into `/data/adb/modules/mystic_wlan/service.sh`, applied automatically post-boot.

---

## Release Artifacts

All release files are located in `Mystic_Releases/`:

| Artifact | Size | Description |
| :--- | :--- | :--- |
| **`Mystic_Kona_myzanori_universal_v1.0.02_ReSukiSU_SUSFS_AnyKernel3.zip`** | 29 MB | **Recommended**. Flashable via TWRP, OrangeFox, KernelSU App, or Magisk. Automatically writes boot partition and installs WLAN + tuning module to `/data/adb/modules/mystic_wlan/`. |
| **`Mystic_WLAN_Tuning_KSU_Module_v1.0.02.zip`** | 3.1 MB | Standalone KernelSU module for the WLAN driver and runtime schedutil/storage optimizations. |
| **`Mystic_9R_myzanori_universal_v1.0.02.img`** | 61 MB | Raw boot image with stock AVB metadata for fastboot flashing on OnePlus 9R (`lemonades`). |
| **`Mystic_9R_myzanori_universal_v1.0.02.Image`** | 50 MB | Raw uncompressed Linux 4.19.325 kernel binary. |

---

## Installation Instructions

### Option 1: AnyKernel3 (Recommended)
1. Download `Mystic_Kona_myzanori_universal_v1.0.02_ReSukiSU_SUSFS_AnyKernel3.zip`.
2. Flash via:
   - **KernelSU App**: Modules tab -> Install from storage -> Select zip.
   - **TWRP / OrangeFox**: Install -> Select zip -> Swipe to confirm.
3. Reboot system. WiFi and runtime tuning will initialize automatically on first boot.

### Option 2: Fastboot (OnePlus 9R)
```bash
# Reboot to bootloader
adb reboot bootloader

# Flash to active boot slot
fastboot flash boot Mystic_9R_myzanori_universal_v1.0.02.img
fastboot reboot

# If on a clean flash without KernelSU modules, flash the standalone module:
# adb push Mystic_WLAN_Tuning_KSU_Module_v1.0.02.zip /sdcard/
# Install via KernelSU manager app.
```

---

## Verification & Subsystem Status (Measured on OOS14)

- **Kernel Version**: `4.19.325-perf-Mystic-9R-myzanori-universal-v1.0.02+`
- **Camera Subsystem**: 8 camera devices detected in `dumpsys media.camera`. Physical sensors (`IMX586`, `IMX481`, `IMX471`, `GC5035`) probe and stream without frame drops.
- **Torch / Flashlight**: All 3 LED channels (`led:torch_0`, `led:torch_1`, `led:torch_2`) fully operational.
- **WiFi**: `wlan0` active, 5GHz connection stable, 0% packet loss.
- **Telephony & Mobile Data**: Vi India 4G LTE VoLTE/VoWiFi verified (`mVoiceRegState=0`, `mDataRegState=0`).
- **Audio**: `konamtpsndcard` active in `/proc/asound/cards`, vendor audio HAL operational.
- **Root & Stealth**: ReSukiSU root active (`uid=0`), SUSFS v2.3.0 with all 9 features confirmed active.
