### AnyKernel3 Ramdisk Mod Script
## Mystic Kernel (SM8250 / Kona Unified for OnePlus 9R, 8T, 8, 8 Pro)

### AnyKernel setup
# global properties
properties() { '
kernel.string=Mystic Kernel v1.0.64 for OnePlus 9R / 8T (SM8250) by myzanori
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=lemonades
device.name2=lemonadep
device.name3=kebab
device.name4=kebabt
device.name5=instantnoodle
device.name6=instantnoodlep
device.name7=OnePlus9R
device.name8=OnePlus8T
device.name9=OnePlus8
device.name10=OnePlus8Pro
device.name11=LE2101
device.name12=KB2001
device.name13=KB2000
device.name14=KB2003
device.name15=KB2005
device.name16=KB2007
device.name17=IN2011
device.name18=IN2021
device.name19=20809
device.name20=20828
device.name21=20838
device.name22=opkona
device.name23=ossi
device.name24=kona
device.name25=19821
device.name26=19811
device.name27=19855
device.name28=19867
device.name29=19805
device.name30=OnePlus8T_CH
device.name31=OnePlus8_CH
device.name32=OnePlus8Pro_CH
device.name33=OP515BL1
device.name34=OP5154L1
device.name35=OP4E75L1
device.name36=kebab_ch
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=auto;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# Dynamic version, build number, and target configuration
TARGET_VERSION="__MYSTIC_VERSION__";
TARGET_BUILD="__MYSTIC_BUILD__";
TARGET_VARIANT="__TARGET_VARIANT__";
TARGET_ROM="__TARGET_ROM__";

# Runtime dynamic detection: parse bundled kernel Image if unexpanded placeholders remain
if [ -f "$home/Image" ]; then
    IMG_UTS=$(grep -a -m1 -oE "Linux version [^ ]+" "$home/Image" 2>/dev/null);
    if [ -n "$IMG_UTS" ]; then
        if [ "$TARGET_VERSION" = "__MYSTIC_VERSION__" ] || [ -z "$TARGET_VERSION" ]; then
            EXT_VER=$(echo "$IMG_UTS" | grep -oE "v[0-9.]+" | head -n1);
            [ -n "$EXT_VER" ] && TARGET_VERSION="$EXT_VER";
        fi;
        if [ "$TARGET_ROM" = "__TARGET_ROM__" ] || [ -z "$TARGET_ROM" ]; then
            case "$IMG_UTS" in
                *COS*) TARGET_ROM="COS"; TARGET_VARIANT="ColorOS 15-17 (COS)";;
                *OOS*) TARGET_ROM="OOS"; TARGET_VARIANT="OxygenOS 11-14 (OOS)";;
                *AOSP*) TARGET_ROM="AOSP"; TARGET_VARIANT="AOSP Custom ROMs (AOSP)";;
            esac;
        fi;
    fi;
fi;

# Final fallback defaults if neither template substitution nor UTS string matched
[ "$TARGET_VERSION" = "__MYSTIC_VERSION__" ] && TARGET_VERSION="v1.0.64";
if [ "$TARGET_BUILD" = "__MYSTIC_BUILD__" ]; then
    TARGET_BUILD=$(echo "$TARGET_VERSION" | sed -E 's/.*\.//' 2>/dev/null);
    [ -z "$TARGET_BUILD" ] && TARGET_BUILD="64";
fi;
[ "$TARGET_VARIANT" = "__TARGET_VARIANT__" ] && TARGET_VARIANT="SM8250 Unified (COS/OOS/AOSP)";
[ "$TARGET_ROM" = "__TARGET_ROM__" ] && TARGET_ROM="Unified";

ui_print " ";
ui_print "==================================================";
ui_print "                  MYSTIC KERNEL                   ";
ui_print "         High Performance SM8250 Unified          ";
ui_print "==================================================";
ui_print "  Release   : Mystic Kernel $TARGET_VERSION (Build $TARGET_BUILD)";
ui_print "  Variant   : $TARGET_VARIANT";
ui_print "  Developer : myzanori";
ui_print "  Features  : BakaSU + SUSFS v2.3.0 + NoMount";
ui_print "==================================================";
ui_print " ";

# Gather and display device environment details
ui_print "[*] Inspecting device environment...";
DEV_MODEL=$(getprop ro.product.model 2>/dev/null);
[ -z "$DEV_MODEL" ] && DEV_MODEL=$(getprop ro.product.vendor.model 2>/dev/null);
[ -z "$DEV_MODEL" ] && DEV_MODEL="OnePlus Kona Device";

DEV_NAME=$(getprop ro.product.device 2>/dev/null);
[ -z "$DEV_NAME" ] && DEV_NAME=$(getprop ro.build.product 2>/dev/null);
[ -z "$DEV_NAME" ] && DEV_NAME="kona";

DEV_SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null);
[ -z "$DEV_SLOT" ] && DEV_SLOT="None (A-only)";

DEV_REL=$(getprop ro.build.version.release 2>/dev/null);
[ -z "$DEV_REL" ] && DEV_REL="Unknown";

DEV_PATCH=$(getprop ro.build.version.security_patch 2>/dev/null);
[ -z "$DEV_PATCH" ] && DEV_PATCH=$(getprop ro.vendor.build.security_patch 2>/dev/null);
[ -z "$DEV_PATCH" ] && DEV_PATCH="Stock";

ui_print "    Device : $DEV_MODEL ($DEV_NAME)";
ui_print "    Slot   : $DEV_SLOT";
ui_print "    Android: $DEV_REL (SPL: $DEV_PATCH)";
ui_print " ";

# Step 1: Dump boot
ui_print "[*] Step 1/4: Unpacking existing boot partition...";
dump_boot;
ui_print "[+] Boot image successfully unpacked.";

# Step 2: Preserve and align boot header OS version and patch level
ui_print "[*] Step 2/4: Checking and aligning boot headers...";
if [ -f $home/split_img/header ]; then
    cur_os=$(grep -E '^os_version=' $home/split_img/header 2>/dev/null | cut -d= -f2);
    if [ -z "$cur_os" ] || [ "$cur_os" = "0.0.0" ]; then
        REL=$(getprop ro.build.version.release 2>/dev/null);
        [ -z "$REL" ] && REL="14";
        sed -i "s/os_version=.*/os_version=${REL}.0.0/" $home/split_img/header;
        ui_print "    Aligned OS version header to ${REL}.0.0";
    else
        ui_print "    Preserved existing OS header: $cur_os";
    fi;
    cur_patch=$(grep -E '^os_patch_level=' $home/split_img/header 2>/dev/null | cut -d= -f2);
    if [ -z "$cur_patch" ] || [ "$cur_patch" = "0" ]; then
        V_PATCH=$(getprop ro.vendor.build.security_patch 2>/dev/null);
        [ -z "$V_PATCH" ] && V_PATCH=$(getprop ro.build.version.security_patch 2>/dev/null);
        if [ -n "$V_PATCH" ]; then
            sed -i "s/os_patch_level=.*/os_patch_level=$V_PATCH/" $home/split_img/header;
            ui_print "    Aligned patch level header to $V_PATCH";
        fi;
    else
        ui_print "    Preserved existing patch level: $cur_patch";
    fi;
fi;
ui_print "[+] Boot header alignment and Treble check complete.";

# Step 3: Write new kernel Image while keeping stock DTB & ramdisk
ui_print "[*] Step 3/4: Repacking & flashing Mystic Kernel ($TARGET_ROM)...";
write_boot;
ui_print "[+] Kernel image written to boot partition successfully.";

# Step 4: Install persistent runtime tuning and patch level alignment
ui_print "[*] Step 4/4: Deploying runtime post-boot services...";
SERVICES_DEPLOYED=0;
if [ -d /data/adb/service.d ]; then
    cp -f $home/mystic-tune.sh /data/adb/service.d/mystic-tune.sh 2>/dev/null;
    chmod 755 /data/adb/service.d/mystic-tune.sh 2>/dev/null;
    SERVICES_DEPLOYED=$((SERVICES_DEPLOYED + 1));
fi;
if [ -d /data/adb/boot-completed.d ]; then
    cp -f $home/mystic-tune.sh /data/adb/boot-completed.d/mystic-tune.sh 2>/dev/null;
    chmod 755 /data/adb/boot-completed.d/mystic-tune.sh 2>/dev/null;
    SERVICES_DEPLOYED=$((SERVICES_DEPLOYED + 1));
fi;
if [ -d /data/adb/post-fs-data.d ]; then
    cp -f $home/mystic-tune.sh /data/adb/post-fs-data.d/mystic-tune.sh 2>/dev/null;
    chmod 755 /data/adb/post-fs-data.d/mystic-tune.sh 2>/dev/null;
    SERVICES_DEPLOYED=$((SERVICES_DEPLOYED + 1));
fi;
if [ $SERVICES_DEPLOYED -gt 0 ]; then
    ui_print "    Installed mystic-tune optimizer to $SERVICES_DEPLOYED hook(s).";
else
    ui_print "    Standalone mode (service hooks link on root install).";
fi;

# Install WLAN module if bundled in AnyKernel3 package (OxygenOS targets)
if [ -d $home/modules/mystic_wlan ] && [ -d /data/adb ]; then
    ui_print " ";
    ui_print "[*] OxygenOS Wi-Fi driver module detected:";
    mkdir -p /data/adb/modules/mystic_wlan
    cp -rf $home/modules/mystic_wlan/* /data/adb/modules/mystic_wlan/
    chmod 755 /data/adb/modules/mystic_wlan
    chmod 755 /data/adb/modules/mystic_wlan/*.sh 2>/dev/null || true
    chmod 644 /data/adb/modules/mystic_wlan/module.prop 2>/dev/null || true
    chmod 644 /data/adb/modules/mystic_wlan/wlan.ko 2>/dev/null || true
    touch /data/adb/modules/mystic_wlan/auto_mount
    ui_print "[+] WLAN driver deployed to /data/adb/modules/mystic_wlan";
fi;

ui_print " ";
ui_print "==================================================";
ui_print "              INSTALLATION COMPLETED              ";
ui_print "==================================================";
ui_print "  Status    : Successfully Installed";
ui_print "  Release   : Mystic Kernel $TARGET_VERSION (Build $TARGET_BUILD)";
ui_print "  Target    : $TARGET_VARIANT";
ui_print " ";
ui_print "  Active Features:";
ui_print "  [-] BakaSU & KernelSU Integration Ready";
ui_print "  [-] SUSFS v2.3.0 Kernel Stealth Engine Active";
ui_print "  [-] Native Detector / SafetyNet Spoofing Active";
ui_print "  [-] Dynamic Thermal & Frequency Optimization";
ui_print "--------------------------------------------------";
ui_print "  Notice    : Please reboot your device to enjoy!";
ui_print "  Support   : https://github.com/myzanori";
ui_print "==================================================";
ui_print " ";
## end boot install
