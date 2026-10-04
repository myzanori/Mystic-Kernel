#!/usr/bin/env bash
set -eu
ROOT=/home/myzanori/Desktop/projects/Oneplus_9R/kernel
cd "$ROOT/jack"

# Source branding metadata
. ./mystic_version.sh

export PATH="$ROOT/clang-10/bin:$ROOT/toolchains/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/clang-10/lib:$ROOT/toolchains/libcompat:${LD_LIBRARY_PATH:-}"
export KCFLAGS="-Wno-strict-prototypes -Wno-missing-prototypes -Wno-unused-function -Wno-unused-variable"

# Export OPLUS feature make-variables
python3 - > "$ROOT/.oplus_env_jack.sh" <<'PY'
import re
for line in open("oplus_native_features.mk"):
    m = re.match(r'^(OPLUS_[A-Z0-9_]+)=(.*)$', line.rstrip("\n"))
    if m:
        k, v = m.group(1), m.group(2)
        print("export %s='%s'" % (k, v.replace("'", "'\\''")))
PY
. "$ROOT/.oplus_env_jack.sh"

CL="$ROOT/clang-10/bin/clang"
MK=(O=out ARCH=arm64 CC="$CL" CLANG_TRIPLE=aarch64-linux-gnu- BRAND_SHOW_FLAG=oneplus
    LD="$ROOT/toolchains/gcc-64/bin/aarch64-linux-android-ld" HOSTCC="$CL" HOSTCXX="$ROOT/clang-10/bin/clang++"
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-)

mkdir -p out

echo ">>> Configuring vendor/kona-perf_defconfig..."
make "${MK[@]}" vendor/kona-perf_defconfig

echo ">>> Applying Mystic OOS16 Branding & Features to .config..."
./scripts/config --file out/.config --set-str LOCALVERSION "$MYSTIC_LOCALVERSION"
./scripts/config --file out/.config --disable LOCALVERSION_AUTO
./scripts/config --file out/.config --disable MODULE_SIG_FORCE
./scripts/config --file out/.config --disable MODVERSIONS
./scripts/config --file out/.config --enable MODULE_FORCE_LOAD

# Enable KSU and SUSFS options
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

# Performance, Networking, and Jitter Fixes
./scripts/config --file out/.config --enable TCP_CONG_ADVANCED
./scripts/config --file out/.config --enable TCP_CONG_BBR
./scripts/config --file out/.config --enable DEFAULT_BBR
./scripts/config --file out/.config --set-str DEFAULT_TCP_CONG "bbr"
./scripts/config --file out/.config --enable NET_SCH_FQ
./scripts/config --file out/.config --enable NET_SCH_FQ_CODEL
./scripts/config --file out/.config --enable WIREGUARD
./scripts/config --file out/.config --enable SLAB_FREELIST_HARDENED
./scripts/config --file out/.config --disable SCHEDSTATS

# I/O Scheduler & Storage
./scripts/config --file out/.config --enable DEFAULT_DEADLINE
./scripts/config --file out/.config --set-str DEFAULT_IOSCHED "deadline"
./scripts/config --file out/.config --disable ZRAM_WRITEBACK

# Modern Android Support (Android 15/16)
./scripts/config --file out/.config --enable ANDROID_BINDERFS
./scripts/config --file out/.config --enable USERFAULTFD
./scripts/config --file out/.config --enable MEMFD_CREATE
./scripts/config --file out/.config --enable FS_VERITY
./scripts/config --file out/.config --enable EROFS_FS
./scripts/config --file out/.config --enable EROFS_FS_ZIP
./scripts/config --file out/.config --enable F2FS_FS_COMPRESSION

echo ">>> Running olddefconfig..."
make "${MK[@]}" olddefconfig

echo ">>> Building Mystic OOS16 Kernel (Image)..."
make -j"$(nproc)" "${MK[@]}" Image
ls -lh out/arch/arm64/boot/Image

echo ">>> Packaging Branded Artifacts..."
ARTIFACTS_DIR="/home/myzanori/Desktop/projects/Oneplus_9R/Mystic_Releases"
mkdir -p "$ARTIFACTS_DIR"

# 1. Named Kernel Image
cp out/arch/arm64/boot/Image "$ARTIFACTS_DIR/${MYSTIC_PREFIX}.Image"

# 2. Named Boot Image (repacked with post-OTA stock boot for 9R)
python3 "$ROOT/repack-boot.py" \
  "$ROOT/rollback-a14-post-ota/boot_b.img" \
  out/arch/arm64/boot/Image \
  "$ARTIFACTS_DIR/${MYSTIC_PREFIX}.img"

# 3. Unified AnyKernel3 Zip
rm -rf ak3 && cp -r "$ROOT/anykernel3" ak3
cp out/arch/arm64/boot/Image ak3/Image
cp build_tools/anykernel.sh ak3/anykernel.sh
python3 - <<PY
import os, zipfile
zf_path = "${ARTIFACTS_DIR}/${MYSTIC_UNIFIED_PREFIX}_${MYSTIC_FLAVOUR}_AnyKernel3.zip"
with zipfile.ZipFile(zf_path, "w", zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk("ak3"):
        if "/.git" in root or root.endswith("/.git"):
            continue
        for f in files:
            if f.endswith(".zip"):
                continue
            p = os.path.join(root, f)
            arc = os.path.relpath(p, "ak3")
            zf.write(p, arc)
print(f"Created: {zf_path}")
PY

echo ">>> BUILD & PACKAGING COMPLETE!"
ls -lh "$ARTIFACTS_DIR"/${MYSTIC_PREFIX}* "$ARTIFACTS_DIR"/${MYSTIC_UNIFIED_PREFIX}*
