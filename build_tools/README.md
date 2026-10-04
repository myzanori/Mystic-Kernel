# OnePlus 9R (SM8250) OxygenOS 14 Kernel with ReSukiSU + SUSFS v2.3.0

This repository contains the source code for the **OnePlus 9R** running **OxygenOS 14 (LE2101_14.0.0.2401 & B100P01)** with **ReSukiSU v4.2.0-rc3** and **SUSFS v2.3.0**.

---

## 🛠 Features

- **Base Tree**: OnePlus OSS `oneplus/sm8250_u_14.0.0_op9r` (matching official OOS 14).
- **Root & Kernel Hooks**: ReSukiSU v4.2.0-rc3 inline hooks + SUSFS v2.3.0.
- **SELinux**: Full Enforcing mode support.
- **Camera Subsystem**: 100% operational (all 8 camera sensors functional).
- **Toolchain**: Clang 10.0.1 + GNU ld (binutils-2.27).
- **Clean Configuration**: No Mount hacks excluded; native F2FS & inlinecrypt parity.

---

## 🚀 Build Instructions

### 1. Prerequisites & Toolchain Setup
Clone the required toolchains into `../`:
```bash
# Clang 10 (ZyC / Proton Clang 10)
# GCC 64-bit cross-compiler
```

### 2. Modules & Devicetree Tree
Clone the vendor modules tree:
```bash
git clone -b oneplus/sm8250_u_14.0.0_op9r --depth=1 \
  https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8250.git oos14-modules
```
Overlay `vendor/` and `techpack/`:
```bash
cp -r oos14-modules/vendor oos14/vendor
cp -r oos14-modules/kernel/msm-4.19/techpack/* oos14/techpack/
```

### 3. ReSukiSU
```bash
git clone -b main https://github.com/ReSukiSU/ReSukiSU.git KernelSU
```

### 4. Build Kernel
```bash
./build_tools/build-oos14-clang10.sh
```

The output `Image` will be located at:
`out/arch/arm64/boot/Image`

### 5. Repack Boot Image
```bash
python3 build_tools/repack-boot.py <stock_boot.img> out/arch/arm64/boot/Image boot-oos14-resukisu-susfs.img
```
