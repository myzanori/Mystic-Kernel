### AnyKernel3 Ramdisk Mod Script
## Mystic Kernel (SM8250 / Kona Unified for OnePlus 9R, 8T, 8, 8 Pro)

### AnyKernel setup
# global properties
properties() { '
kernel.string=Mystic Kernel v1.0.61 for OnePlus 9R / 8T (SM8250) by myzanori
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

ui_print " ";
ui_print "========================================";
ui_print "  Mystic Kernel v1.0.61                 ";
ui_print "  OnePlus 9R & 8T (SM8250 Kona)         ";
ui_print "  BakaSU + SUSFS v2.3.0 + NoMount       ";
ui_print "----------------------------------------";
ui_print "  Developer : myzanori                  ";
ui_print "  GitHub    : https://github.com/myzanori";
ui_print "========================================";
ui_print " ";

# boot install
dump_boot;

# Preserve and align boot header OS version and patch level
if [ -f $home/split_img/header ]; then
    cur_os=$(grep -E '^os_version=' $home/split_img/header 2>/dev/null | cut -d= -f2);
    if [ -z "$cur_os" ] || [ "$cur_os" = "0.0.0" ]; then
        sed -i 's/os_version=.*/os_version=14.0.0/' $home/split_img/header;
    fi;
    cur_patch=$(grep -E '^os_patch_level=' $home/split_img/header 2>/dev/null | cut -d= -f2);
    if [ -z "$cur_patch" ] || [ "$cur_patch" = "0" ]; then
        V_PATCH=$(getprop ro.vendor.build.security_patch 2>/dev/null);
        if [ -n "$V_PATCH" ]; then
            sed -i "s/os_patch_level=.*/os_patch_level=$V_PATCH/" $home/split_img/header;
        fi;
    fi;
fi;

# write new kernel Image while keeping stock DTB & ramdisk
write_boot;

# Install persistent runtime tuning and patch level alignment
if [ -d /data/adb/service.d ]; then
    cp -f $home/mystic-tune.sh /data/adb/service.d/mystic-tune.sh 2>/dev/null;
    chmod 755 /data/adb/service.d/mystic-tune.sh 2>/dev/null;
fi;
if [ -d /data/adb/boot-completed.d ]; then
    cp -f $home/mystic-tune.sh /data/adb/boot-completed.d/mystic-tune.sh 2>/dev/null;
    chmod 755 /data/adb/boot-completed.d/mystic-tune.sh 2>/dev/null;
fi;
if [ -d /data/adb/post-fs-data.d ]; then
    cp -f $home/mystic-tune.sh /data/adb/post-fs-data.d/mystic-tune.sh 2>/dev/null;
    chmod 755 /data/adb/post-fs-data.d/mystic-tune.sh 2>/dev/null;
fi;

# Install WLAN module if bundled in AnyKernel3 package (OxygenOS targets)
if [ -d $home/modules/mystic_wlan ] && [ -d /data/adb ]; then
    ui_print " ";
    ui_print ">> Setting up WLAN driver for OxygenOS...";
    mkdir -p /data/adb/modules/mystic_wlan
    cp -rf $home/modules/mystic_wlan/* /data/adb/modules/mystic_wlan/
    chmod 755 /data/adb/modules/mystic_wlan
    chmod 755 /data/adb/modules/mystic_wlan/*.sh 2>/dev/null || true
    chmod 644 /data/adb/modules/mystic_wlan/module.prop 2>/dev/null || true
    chmod 644 /data/adb/modules/mystic_wlan/wlan.ko 2>/dev/null || true
    touch /data/adb/modules/mystic_wlan/auto_mount
    ui_print ">> WLAN module installed to /data/adb/modules/mystic_wlan";
fi;

ui_print " ";
ui_print ">> Installation Successful!";
ui_print ">> Enjoy Mystic Kernel by myzanori!";
ui_print " ";
## end boot install
