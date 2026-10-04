#!/usr/bin/env bash
set -eu
ROOT=/home/myzanori/Desktop/projects/Oneplus_9R/kernel
cd "$ROOT/oos14"

# Source branding metadata
. ./mystic_version.sh

export PATH="$ROOT/clang-10/bin:$ROOT/toolchains/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/clang-10/lib:$ROOT/toolchains/libcompat:${LD_LIBRARY_PATH:-}"
export KCFLAGS="-Wno-strict-prototypes -Wno-missing-prototypes -Wno-unused-function -Wno-unused-variable"

# Export OPLUS feature make-variables so Kbuild objs behind `ifeq (...)` get selected
python3 - > "$ROOT/.oplus_env_a14.sh" <<'PY'
import re
for line in open("oplus_native_features.mk"):
    m = re.match(r'^(OPLUS_[A-Z0-9_]+)=(.*)$', line.rstrip("\n"))
    if m:
        k, v = m.group(1), m.group(2)
        print("export %s='%s'" % (k, v.replace("'", "'\\''")))
PY
. "$ROOT/.oplus_env_a14.sh"

CL="$ROOT/clang-10/bin/clang"
MK=(O=out ARCH=arm64 CC="$CL" CLANG_TRIPLE=aarch64-linux-gnu- BRAND_SHOW_FLAG=oneplus
    LD="$ROOT/toolchains/gcc-64/bin/aarch64-linux-android-ld" HOSTCC="$CL" HOSTCXX="$ROOT/clang-10/bin/clang++"
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-)

echo ">>> Applying branding to .config: $MYSTIC_LOCALVERSION"
./scripts/config --file out/.config --set-str LOCALVERSION "$MYSTIC_LOCALVERSION"
./scripts/config --file out/.config --disable LOCALVERSION_AUTO
./scripts/config --file out/.config --disable MODULE_SIG_FORCE

echo ">>> olddefconfig A14"
make "${MK[@]}" olddefconfig

echo ">>> build A14 (clang10, Image)"
make -j"$(nproc)" "${MK[@]}" Image
ls -la out/arch/arm64/boot/Image

echo ">>> Packaging Branded Artifacts..."
ARTIFACTS_DIR="/home/myzanori/Desktop/projects/Oneplus_9R/Mystic_Releases"
mkdir -p "$ARTIFACTS_DIR"

# 1. Named Kernel Image
cp out/arch/arm64/boot/Image "$ARTIFACTS_DIR/${MYSTIC_PREFIX}.Image"

# 2. Named Boot Image (repacked with post-OTA stock boot)
python3 "$ROOT/repack-boot.py" \
  "$ROOT/rollback-a14-post-ota/boot_b.img" \
  out/arch/arm64/boot/Image \
  "$ARTIFACTS_DIR/${MYSTIC_PREFIX}.img"

# Also update root boot.img
cp "$ARTIFACTS_DIR/${MYSTIC_PREFIX}.img" /home/myzanori/Desktop/projects/Oneplus_9R/boot-oos14-resukisu-susfs.img

# 3. AnyKernel3 Zip
cp out/arch/arm64/boot/Image "$ROOT/anykernel3/Image"
python3 - <<'PY'
import os, zipfile
ak3_dir = "/home/myzanori/Desktop/projects/Oneplus_9R/kernel/anykernel3"
prefix = os.environ.get("MYSTIC_PREFIX", "Mystic_9R_myzanori_OOS14_v1.0")
flavour = os.environ.get("MYSTIC_FLAVOUR", "ReSukiSU_SUSFS")
out_zip = f"/home/myzanori/Desktop/projects/Oneplus_9R/Mystic_Releases/{prefix}_{flavour}_AnyKernel3.zip"

with zipfile.ZipFile(out_zip, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(ak3_dir):
        for file in files:
            if file.endswith(".zip"): continue
            fp = os.path.join(root, file)
            zf.write(fp, os.path.relpath(fp, ak3_dir))
print(f"Created AnyKernel3 Zip: {out_zip} ({os.path.getsize(out_zip)} bytes)")
PY

# 4. Fastboot Zip
python3 - <<'PY'
import os, zipfile
prefix = os.environ.get("MYSTIC_PREFIX", "Mystic_9R_myzanori_OOS14_v1.0")
out_zip = f"/home/myzanori/Desktop/projects/Oneplus_9R/Mystic_Releases/{prefix}_Fastboot.zip"
pkg_dir = "/home/myzanori/Desktop/projects/Oneplus_9R/OnePlus9R_OOS14_Kernel_4.19.157_ReSukiSU_SUSFS"

# update boot image in images/
img_src = f"/home/myzanori/Desktop/projects/Oneplus_9R/Mystic_Releases/{prefix}.img"
import shutil
shutil.copyfile(img_src, os.path.join(pkg_dir, "images/boot-oos14-official-resukisu-susfs.img"))

with zipfile.ZipFile(out_zip, 'w', zipfile.ZIP_DEFLATED) as zf:
    for folder in ['images', 'scripts', 'tools']:
        full_f = os.path.join(pkg_dir, folder)
        for root, dirs, files in os.walk(full_f):
            for file in files:
                fp = os.path.join(root, file)
                zf.write(fp, os.path.relpath(fp, pkg_dir))
    readme = os.path.join(pkg_dir, 'README.md')
    if os.path.exists(readme):
        zf.write(readme, 'README.md')
print(f"Created Fastboot Zip: {out_zip} ({os.path.getsize(out_zip)} bytes)")
PY

echo "=== Mystic Kernel Build & Packaging Complete ==="
ls -lh "$ARTIFACTS_DIR"
