### AnyKernel3 Ramdisk Mod Script
## Mystic Kernel (OnePlus 9R lemonades / LE2101)

### AnyKernel setup
# global properties
properties() { '
kernel.string=Mystic Kernel v1.0.50 for OnePlus 9R (OOS14) by myzanori
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=lemonades
device.name2=lemonadep
device.name3=OnePlus9R
device.name4=LE2101
device.name5=20809
device.name6=20828
device.name7=20838
supported.versions=11-16
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
ui_print "  Mystic Kernel v1.0.50 (OOS14)         ";
ui_print "  OnePlus 9R (lemonades / LE2101)       ";
ui_print "  ReSukiSU + SUSFS v2.3.0 Stable        ";
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
    V_PATCH=$(getprop ro.vendor.build.security_patch 2>/dev/null);
    if [ -n "$V_PATCH" ]; then
        sed -i "s/os_patch_level=.*/os_patch_level=$V_PATCH/" $home/split_img/header;
    fi;
fi;
# write new kernel Image while keeping stock DTB & ramdisk
write_boot;

# install mystic wlan and tuning helper module
ui_print " ";
ui_print ">> Setting up WLAN driver & runtime optimizations...";
mount /data 2>/dev/null;
if [ -d /data/adb ]; then
  mkdir -p /data/adb/modules/mystic_wlan
  cp -rf $AKHOME/modules/mystic_wlan/* /data/adb/modules/mystic_wlan/
  chmod 755 /data/adb/modules/mystic_wlan
  chmod 755 /data/adb/modules/mystic_wlan/*.sh
  chmod 644 /data/adb/modules/mystic_wlan/module.prop
  chmod 644 /data/adb/modules/mystic_wlan/wlan.ko
  touch /data/adb/modules/mystic_wlan/auto_mount
  ui_print ">> Mystic WLAN module & tuning installed to /data/adb/modules/mystic_wlan";
else
  ui_print ">> /data/adb not accessible in current environment.";
  ui_print ">> You can flash Mystic_WLAN_Tuning_KSU_Module_v1.0.30.zip in KernelSU manager.";
fi;

ui_print " ";
ui_print ">> Installation Successful!";
ui_print ">> Enjoy Mystic Kernel by myzanori!";
ui_print " ";
## end boot install
