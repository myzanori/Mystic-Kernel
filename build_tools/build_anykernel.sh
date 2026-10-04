#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$KERNEL_DIR"

# 1. Source Branding Metadata
. "$KERNEL_DIR/mystic_version.sh"

echo "=========================================================="
echo " Building: $MYSTIC_NAME $MYSTIC_VERSION ($MYSTIC_ROM)"
echo " Device  : OnePlus $MYSTIC_DEVICE (Kona SM8250)"
echo " LocalVer: $MYSTIC_LOCALVERSION"
echo "=========================================================="

# 2. Export OPLUS feature make-variables
python3 - > "$KERNEL_DIR/.oplus_env.sh" <<'PY'
import re
for line in open("oplus_native_features.mk"):
    m = re.match(r'^(OPLUS_[A-Z0-9_]+)=(.*)$', line.rstrip("\n"))
    if m:
        k, v = m.group(1), m.group(2)
        print("export %s='%s'" % (k, v.replace("'", "'\\''")))
PY
. "$KERNEL_DIR/.oplus_env.sh"

# 3. Compiler Configuration
CLANG_DIR="${CLANG_DIR:-$KERNEL_DIR/clang-10}"
GCC64_DIR="${GCC64_DIR:-$KERNEL_DIR/toolchains/gcc-64}"
GCC32_DIR="${GCC32_DIR:-$KERNEL_DIR/toolchains/gcc-32}"

export PATH="$CLANG_DIR/bin:$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:${LD_LIBRARY_PATH:-}"
export KCFLAGS="-Wno-strict-prototypes -Wno-missing-prototypes -Wno-unused-function -Wno-unused-variable"

CL="$CLANG_DIR/bin/clang"
LD_BIN="$GCC64_DIR/bin/aarch64-linux-android-ld"
STRIP_BIN="$CLANG_DIR/bin/llvm-strip"

if [ ! -x "$LD_BIN" ]; then
    LD_BIN="aarch64-linux-gnu-ld"
fi
if [ ! -x "$STRIP_BIN" ]; then
    STRIP_BIN="llvm-strip"
fi

MK=(O=out ARCH=arm64 CC="$CL" CLANG_TRIPLE=aarch64-linux-gnu- BRAND_SHOW_FLAG=oneplus
    LD="$LD_BIN" HOSTCC="$CL" HOSTCXX="$CLANG_DIR/bin/clang++"
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-)

mkdir -p out

# 4. Defconfig & Branding Options
echo ">>> Configuring vendor/kona-perf_defconfig..."
make "${MK[@]}" vendor/kona-perf_defconfig

echo ">>> Applying Mystic Kernel Configuration..."
./scripts/config --file out/.config --set-str LOCALVERSION "$MYSTIC_LOCALVERSION"
./scripts/config --file out/.config --disable LOCALVERSION_AUTO
./scripts/config --file out/.config --disable MODULE_SIG_FORCE
./scripts/config --file out/.config --disable MODVERSIONS
./scripts/config --file out/.config --enable MODULE_FORCE_LOAD

# KSU & SUSFS
./scripts/config --file out/.config --enable KSU
./scripts/config --file out/.config --enable KSU_MULTI_MANAGER_SUPPORT
./scripts/config --file out/.config --enable KSU_SUSFS
./scripts/config --file out/.config --enable KSU_SUSFS_SUS_PATH
./scripts/config --file out/.config --enable KSU_SUSFS_SUS_MOUNT
./scripts/config --file out/.config --enable KSU_SUSFS_SUS_KSTAT
./scripts/config --file out/.config --enable KSU_SUSFS_SPOOF_UNAME
./scripts/config --file out/.config --enable KSU_SUSFS_ENABLE_LOG
./scripts/config --file out/.config --enable KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS
./scripts/config --file out/.config --enable KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
./scripts/config --file out/.config --enable KSU_SUSFS_OPEN_REDIRECT
./scripts/config --file out/.config --enable KSU_SUSFS_SUS_MAP

# Networking & Latency
./scripts/config --file out/.config --enable TCP_CONG_ADVANCED
./scripts/config --file out/.config --enable TCP_CONG_BBR
./scripts/config --file out/.config --enable DEFAULT_BBR
./scripts/config --file out/.config --set-str DEFAULT_TCP_CONG "bbr"
./scripts/config --file out/.config --enable NET_SCH_FQ
./scripts/config --file out/.config --enable NET_SCH_FQ_CODEL
./scripts/config --file out/.config --enable WIREGUARD
./scripts/config --file out/.config --enable SLAB_FREELIST_HARDENED
./scripts/config --file out/.config --disable SCHEDSTATS

# I/O Scheduler & Filesystems
./scripts/config --file out/.config --enable DEFAULT_DEADLINE
./scripts/config --file out/.config --set-str DEFAULT_IOSCHED "deadline"
./scripts/config --file out/.config --disable ZRAM_WRITEBACK
./scripts/config --file out/.config --enable ANDROID_BINDERFS
./scripts/config --file out/.config --enable USERFAULTFD
./scripts/config --file out/.config --enable MEMFD_CREATE
./scripts/config --file out/.config --enable FS_VERITY
./scripts/config --file out/.config --enable EROFS_FS
./scripts/config --file out/.config --enable EROFS_FS_ZIP
./scripts/config --file out/.config --enable F2FS_FS_COMPRESSION

echo ">>> Applying olddefconfig..."
yes "" | make "${MK[@]}" olddefconfig

# 5. Build Kernel Image & Modules
echo ">>> Building Image and modules..."
make -j"$(nproc)" "${MK[@]}" Image modules

if [ ! -f out/arch/arm64/boot/Image ]; then
    echo "[-] Error: out/arch/arm64/boot/Image was not generated!"
    exit 1
fi

# 6. Assemble Single AnyKernel3 Package
echo ">>> Packaging single AnyKernel3 Zip..."
AK3_DIR="$KERNEL_DIR/ak3_build"
rm -rf "$AK3_DIR"

if [ -d "$KERNEL_DIR/ak3" ]; then
    cp -rf "$KERNEL_DIR/ak3" "$AK3_DIR"
else
    git clone --depth=1 https://github.com/osm0sis/AnyKernel3 "$AK3_DIR"
fi

# Copy Kernel Image
cp out/arch/arm64/boot/Image "$AK3_DIR/Image"

# Copy AnyKernel script
cp "$KERNEL_DIR/build_tools/anykernel.sh" "$AK3_DIR/anykernel.sh"

# Strip & Copy WLAN driver
mkdir -p "$AK3_DIR/modules/mystic_wlan"
cp -rf "$KERNEL_DIR/build_tools/ak3_modules/mystic_wlan/"* "$AK3_DIR/modules/mystic_wlan/"

if [ -f out/drivers/staging/qcacld-3.0/wlan.ko ]; then
    echo ">>> Stripping wlan.ko..."
    "$STRIP_BIN" --strip-unneeded -o "$AK3_DIR/modules/mystic_wlan/wlan.ko" out/drivers/staging/qcacld-3.0/wlan.ko
fi

# Create Release Output Directory
RELEASE_OUT="$KERNEL_DIR/release_out"
rm -rf "$RELEASE_OUT"
mkdir -p "$RELEASE_OUT"

ZIP_NAME="${MYSTIC_PREFIX}_${MYSTIC_FLAVOUR}_AnyKernel3.zip"
ZIP_PATH="$RELEASE_OUT/$ZIP_NAME"

python3 - <<PY
import os, zipfile
ak3_dir = "$AK3_DIR"
out_zip = "$ZIP_PATH"

with zipfile.ZipFile(out_zip, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(ak3_dir):
        if '/.git' in root or root.endswith('/.git'):
            continue
        for file in files:
            if file.endswith('.zip'):
                continue
            fp = os.path.join(root, file)
            zf.write(fp, os.path.relpath(fp, ak3_dir))

print(f"Successfully generated single AnyKernel3 release: {out_zip} ({os.path.getsize(out_zip) / (1024*1024):.2f} MB)")
PY

rm -rf "$AK3_DIR"
echo "=========================================================="
echo " Build & Packaging Complete: $ZIP_PATH"
echo "=========================================================="
