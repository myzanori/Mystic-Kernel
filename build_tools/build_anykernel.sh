#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$KERNEL_DIR"

MODE="${1:-all}"

# 1. Source Branding Metadata
. "$KERNEL_DIR/mystic_version.sh"

echo "=========================================================="
echo " Building: $MYSTIC_NAME $MYSTIC_VERSION (Build $MYSTIC_BUILD)"
echo " Device  : OnePlus $MYSTIC_DEVICE (Kona SM8250)"
echo " Mode    : $MODE"
echo "=========================================================="

# 2. Manage OPLUS proprietary feature environment per target
export_oplus_env() {
    echo ">>> Exporting OPLUS proprietary feature environment..."
    python3 - > "$KERNEL_DIR/.oplus_env.sh" <<'PY'
import re
for line in open("oplus_native_features.mk"):
    m = re.match(r'^(OPLUS_[A-Z0-9_]+)=(.*)$', line.rstrip("\n"))
    if m:
        k, v = m.group(1), m.group(2)
        print("export %s='%s'" % (k, v.replace("'", "'\\''")))
PY
    . "$KERNEL_DIR/.oplus_env.sh"
}

unset_oplus_env() {
    echo ">>> Purging OPLUS proprietary feature environment for pure AOSP..."
    if [ -f "$KERNEL_DIR/.oplus_env.sh" ]; then
        while IFS= read -r var; do
            [ -n "$var" ] && unset "$var" || true
        done < <(grep -oE 'export [A-Z0-9_]+' "$KERNEL_DIR/.oplus_env.sh" | awk '{print $2}')
    fi
}

# 3. Compiler Configuration
if [ -z "${CLANG_DIR:-}" ]; then
    if [ -d "$KERNEL_DIR/clang-10" ]; then
        CLANG_DIR="$KERNEL_DIR/clang-10"
    elif [ -d "$KERNEL_DIR/../clang-10" ]; then
        CLANG_DIR="$KERNEL_DIR/../clang-10"
    fi
fi
if [ -z "${GCC64_DIR:-}" ]; then
    if [ -d "$KERNEL_DIR/toolchains/gcc-64" ]; then
        GCC64_DIR="$KERNEL_DIR/toolchains/gcc-64"
    elif [ -d "$KERNEL_DIR/../toolchains/gcc-64" ]; then
        GCC64_DIR="$KERNEL_DIR/../toolchains/gcc-64"
    fi
fi
if [ -z "${GCC32_DIR:-}" ]; then
    if [ -d "$KERNEL_DIR/toolchains/gcc-32" ]; then
        GCC32_DIR="$KERNEL_DIR/toolchains/gcc-32"
    elif [ -d "$KERNEL_DIR/../toolchains/gcc-32" ]; then
        GCC32_DIR="$KERNEL_DIR/../toolchains/gcc-32"
    fi
fi

if [ -d "$GCC64_DIR/bin" ]; then
    for f in "$GCC64_DIR"/bin/aarch64-linux-android-*; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        gnu_name="aarch64-linux-gnu-${base#aarch64-linux-android-}"
        if [ ! -f "$GCC64_DIR/bin/$gnu_name" ]; then
            ln -sf "$f" "$GCC64_DIR/bin/$gnu_name" 2>/dev/null || true
        fi
    done
fi
if [ -d "$GCC32_DIR/bin" ]; then
    for f in "$GCC32_DIR"/bin/arm-linux-androideabi-*; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        gnu_name="arm-linux-gnueabi-${base#arm-linux-androideabi-}"
        if [ ! -f "$GCC32_DIR/bin/$gnu_name" ]; then
            ln -sf "$f" "$GCC32_DIR/bin/$gnu_name" 2>/dev/null || true
        fi
    done
fi

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

# Configure ccache if available
if command -v ccache >/dev/null 2>&1; then
    export CCACHE_DIR="${CCACHE_DIR:-$HOME/.cache/ccache}"
    mkdir -p "$CCACHE_DIR"
    export CCACHE_MAXSIZE="3G"
    export CCACHE_COMPRESS=1
    export CCACHE_SLOPPINESS="file_macro,time_macros,include_file_mtime,include_file_ctime"
    CC_BIN="ccache $CL"
    HOSTCC_BIN="ccache $CL"
    HOSTCXX_BIN="ccache $CLANG_DIR/bin/clang++"
    echo ">>> ccache enabled (Cache dir: $CCACHE_DIR)"
    ccache -s 2>/dev/null || true
else
    CC_BIN="$CL"
    HOSTCC_BIN="$CL"
    HOSTCXX_BIN="$CLANG_DIR/bin/clang++"
fi

# Create Release Output Directory
RELEASE_OUT="$KERNEL_DIR/release_out"
mkdir -p "$RELEASE_OUT"
rm -f "$RELEASE_OUT"/*.zip

if [ -d "$KERNEL_DIR/build_tools/manager" ]; then
    cp -f "$KERNEL_DIR/build_tools/manager/"*.apk "$RELEASE_OUT/" 2>/dev/null || true
fi

# Apply Baseline Mystic Kernel Configurations
apply_mystic_configs() {
    local CFG="$1"
    local TARGET_LOCALVER="$2"

    echo ">>> Applying Baseline Mystic Kernel Configurations to $CFG..."
    ./scripts/config --file "$CFG" --set-str LOCALVERSION "$TARGET_LOCALVER"
    ./scripts/config --file "$CFG" --disable LOCALVERSION_AUTO
    ./scripts/config --file "$CFG" --disable MODULE_SIG_FORCE

    # VINTF Compatibility & Module Loading
    ./scripts/config --file "$CFG" --disable MODVERSIONS
    ./scripts/config --file "$CFG" --enable MODULE_FORCE_LOAD
    ./scripts/config --file "$CFG" --enable RD_LZ4

    # KSU & SUSFS
    ./scripts/config --file "$CFG" --enable KSU
    ./scripts/config --file "$CFG" --enable KSU_MULTI_MANAGER_SUPPORT
    ./scripts/config --file "$CFG" --enable KSU_SUSFS
    ./scripts/config --file "$CFG" --enable KSU_SUSFS_SUS_PATH
    ./scripts/config --file "$CFG" --enable KSU_SUSFS_SUS_MOUNT
    ./scripts/config --file "$CFG" --enable KSU_SUSFS_SUS_KSTAT
    ./scripts/config --file "$CFG" --enable KSU_SUSFS_SPOOF_UNAME
    ./scripts/config --file "$CFG" --enable KSU_SUSFS_ENABLE_LOG
    ./scripts/config --file "$CFG" --enable KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS
    ./scripts/config --file "$CFG" --enable KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
    ./scripts/config --file "$CFG" --enable KSU_SUSFS_OPEN_REDIRECT
    ./scripts/config --file "$CFG" --enable KSU_SUSFS_SUS_MAP

    # Kernel-side NoMount
    ./scripts/config --file "$CFG" --enable NOMOUNT

    # Networking & Latency
    ./scripts/config --file "$CFG" --enable TCP_CONG_ADVANCED
    ./scripts/config --file "$CFG" --enable TCP_CONG_BBR
    ./scripts/config --file "$CFG" --enable TCP_CONG_WESTWOOD
    ./scripts/config --file "$CFG" --enable DEFAULT_BBR
    ./scripts/config --file "$CFG" --set-str DEFAULT_TCP_CONG "bbr"
    ./scripts/config --file "$CFG" --enable NET_SCH_FQ
    ./scripts/config --file "$CFG" --enable NET_SCH_FQ_CODEL
    ./scripts/config --file "$CFG" --enable WIREGUARD
    ./scripts/config --file "$CFG" --enable SLAB_FREELIST_HARDENED
    ./scripts/config --file "$CFG" --disable SCHEDSTATS

    # Timer Frequency (300Hz aligns evenly with 60/90/120Hz display refresh)
    ./scripts/config --file "$CFG" --disable HZ_250
    ./scripts/config --file "$CFG" --enable HZ_300
    ./scripts/config --file "$CFG" --set-val HZ 300

    # Power-Efficient Workqueues (offload non-critical tasks to efficient cores)
    ./scripts/config --file "$CFG" --enable WQ_POWER_EFFICIENT
    ./scripts/config --file "$CFG" --enable WQ_POWER_EFFICIENT_DEFAULT

    # I/O Scheduler & Filesystems
    ./scripts/config --file "$CFG" --enable IOSCHED_BFQ
    ./scripts/config --file "$CFG" --enable BFQ_GROUP_IOSCHED
    ./scripts/config --file "$CFG" --enable DEFAULT_DEADLINE
    ./scripts/config --file "$CFG" --set-str DEFAULT_IOSCHED "deadline"
    ./scripts/config --file "$CFG" --enable CRYPTO_ZSTD
    ./scripts/config --file "$CFG" --enable ZRAM
    ./scripts/config --file "$CFG" --disable ZRAM_WRITEBACK
    ./scripts/config --file "$CFG" --enable ANDROID_BINDERFS
    ./scripts/config --file "$CFG" --enable USERFAULTFD
    ./scripts/config --file "$CFG" --enable MEMFD_CREATE
    ./scripts/config --file "$CFG" --enable FS_VERITY
    ./scripts/config --file "$CFG" --enable EROFS_FS
    ./scripts/config --file "$CFG" --enable EROFS_FS_ZIP
    ./scripts/config --file "$CFG" --enable F2FS_FS_COMPRESSION

    # Disable un-tuned DAMON reclaim to prevent idle memory scan CPU drain
    ./scripts/config --file "$CFG" --disable DAMON
    ./scripts/config --file "$CFG" --disable DAMON_PADDR
    ./scripts/config --file "$CFG" --disable DAMON_RECLAIM
}

# Function to build and package target
build_target_pkg() {
    local TARGET_ROM="$1"
    local TARGET_DESC="$2"
    local INCLUDE_WLAN="$3"

    local TARGET_LOCALVER="-perf-Mystic-Kona-myzanori-${TARGET_ROM}-v${MYSTIC_VERSION}"
    echo ""
    echo "=========================================================="
    echo ">>> Building Target: $TARGET_ROM ($TARGET_DESC)"
    echo ">>> LOCALVERSION   : $TARGET_LOCALVER"
    echo "=========================================================="

    local TARGET_OUT="$KERNEL_DIR/out_${TARGET_ROM,,}"
    mkdir -p "$TARGET_OUT"

    local TARGET_MK=(O="$TARGET_OUT" ARCH=arm64 CC="$CC_BIN" CLANG_TRIPLE=aarch64-linux-gnu- BRAND_SHOW_FLAG=oneplus
        LD="$LD_BIN" HOSTCC="$HOSTCC_BIN" HOSTCXX="$HOSTCXX_BIN"
        CROSS_COMPILE=aarch64-linux-gnu-
        CROSS_COMPILE_ARM32=arm-linux-gnueabi-)

    if [ "$TARGET_ROM" = "AOSP" ]; then
        unset_oplus_env
        local DEFCONFIG="vendor/kona-aosp_defconfig"
    else
        export_oplus_env
        local DEFCONFIG="vendor/kona-perf_defconfig"
    fi

    echo ">>> Configuring $DEFCONFIG into $TARGET_OUT..."
    make "${TARGET_MK[@]}" "$DEFCONFIG"

    apply_mystic_configs "$TARGET_OUT/.config" "$TARGET_LOCALVER"

    make "${TARGET_MK[@]}" olddefconfig
    make -j"$(nproc)" "${TARGET_MK[@]}" Image modules

    if [ ! -f "$TARGET_OUT/arch/arm64/boot/Image" ]; then
        echo "[-] Error: $TARGET_OUT/arch/arm64/boot/Image was not generated!"
        exit 1
    fi

    echo ">>> Packaging AnyKernel3 Zip for $TARGET_ROM..."
    local AK3_DIR="$KERNEL_DIR/ak3_build_${TARGET_ROM}"
    rm -rf "$AK3_DIR"

    if [ -d "$KERNEL_DIR/ak3" ]; then
        cp -rf "$KERNEL_DIR/ak3" "$AK3_DIR"
    else
        git clone --depth=1 https://github.com/osm0sis/AnyKernel3 "$AK3_DIR"
    fi

    # Copy Kernel Image
    cp "$TARGET_OUT/arch/arm64/boot/Image" "$AK3_DIR/Image"

    # Copy and customize AnyKernel script
    sed -e "s/Mystic Kernel v[0-9.]* (ColorOS 15)/Mystic Kernel v${MYSTIC_VERSION} (${TARGET_DESC})/g" \
        -e "s/kernel.string=.*/kernel.string=Mystic Kernel v${MYSTIC_VERSION} (${TARGET_DESC}) for OnePlus Kona by myzanori/g" \
        "$KERNEL_DIR/build_tools/anykernel.sh" > "$AK3_DIR/anykernel.sh"

    cp "$KERNEL_DIR/build_tools/mystic-tune.sh" "$AK3_DIR/mystic-tune.sh"
    if [ -f "$KERNEL_DIR/build_tools/tools/ak3-core.sh" ]; then
        mkdir -p "$AK3_DIR/tools"
        cp -f "$KERNEL_DIR/build_tools/tools/ak3-core.sh" "$AK3_DIR/tools/ak3-core.sh"
    fi

    # Bundle WLAN module for OxygenOS if requested
    if [ "$INCLUDE_WLAN" = "1" ]; then
        if [ -d "$KERNEL_DIR/build_tools/ak3_modules/mystic_wlan" ]; then
            echo ">>> Bundling WLAN module for $TARGET_ROM..."
            mkdir -p "$AK3_DIR/modules/mystic_wlan"
            cp -rf "$KERNEL_DIR/build_tools/ak3_modules/mystic_wlan/"* "$AK3_DIR/modules/mystic_wlan/"
            if [ -f "$TARGET_OUT/drivers/staging/qcacld-3.0/wlan.ko" ]; then
                echo ">>> Stripping and embedding wlan.ko..."
                "$STRIP_BIN" --strip-unneeded -o "$AK3_DIR/modules/mystic_wlan/wlan.ko" "$TARGET_OUT/drivers/staging/qcacld-3.0/wlan.ko"
            fi
        fi
    fi

    local ZIP_NAME="Mystic_${MYSTIC_BUILD}_${TARGET_ROM}.zip"
    local ZIP_PATH="$RELEASE_OUT/$ZIP_NAME"

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

print(f"Successfully generated release zip: {out_zip} ({os.path.getsize(out_zip) / (1024*1024):.2f} MB)")
PY

    rm -rf "$AK3_DIR"
    echo "=========================================================="
    echo " Target Complete: $ZIP_PATH"
    echo "=========================================================="
}

case "$MODE" in
    cos)
        build_target_pkg "COS" "ColorOS 15-17" 0
        ;;
    oos)
        build_target_pkg "OOS" "OxygenOS 11-14" 1
        ;;
    aosp)
        build_target_pkg "AOSP" "AOSP" 0
        ;;
    all|*)
        build_target_pkg "COS" "ColorOS 15-17" 0
        build_target_pkg "AOSP" "AOSP" 0
        build_target_pkg "OOS" "OxygenOS 11-14" 1
        ;;
esac

echo ""
echo "=========================================================="
echo " All Builds Complete! Artifacts in $RELEASE_OUT:"
ls -lh "$RELEASE_OUT"/*.zip
if command -v ccache >/dev/null 2>&1; then
    echo "----------------------------------------------------------"
    echo " ccache Hit Statistics:"
    ccache -s 2>/dev/null || true
fi
echo "=========================================================="
