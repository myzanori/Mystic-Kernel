#!/system/bin/sh
# ==============================================================================
# Mystic Kernel — runtime tuning & stability daemon
# ==============================================================================

LOG=/data/adb/mystic-tune.log
exec >> "$LOG" 2>&1
echo "=== $(date) mystic-tune start (uptime $(cut -d. -f1 /proc/uptime 2>/dev/null)s) ==="

# Align security patch level to prevent "Internal Problem" warning dialog on ColorOS/OOS
V_PATCH="$(getprop ro.vendor.build.security_patch)"
S_PATCH="$(getprop ro.build.version.security_patch)"
if [ -n "$V_PATCH" ] && [ -n "$S_PATCH" ] && [ "$S_PATCH" != "$V_PATCH" ]; then
    resetprop -n ro.build.version.security_patch "$V_PATCH" 2>/dev/null
fi

apply_tuning() {
    resetprop -n ro.boot.vbmeta.device_state unlocked 2>/dev/null
    resetprop -n vendor.boot.vbmeta.device_state unlocked 2>/dev/null

    # Silence SELinux audit denial flood & DAMON reclaim background scanner
    [ -w /proc/fs/selinux/enable_audit ] && echo 0 > /proc/fs/selinux/enable_audit 2>/dev/null
    [ -w /sys/module/damon_reclaim/parameters/enabled ] && echo N > /sys/module/damon_reclaim/parameters/enabled 2>/dev/null
    # 1. Memory Tuning (Smooth responsiveness profile - eliminates swap thrashing)
    echo 60 > /proc/sys/vm/swappiness 2>/dev/null
    [ -w /proc/sys/vm/direct_swappiness ] && echo 60 > /proc/sys/vm/direct_swappiness 2>/dev/null
    echo 50 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    echo 60 > /proc/sys/vm/dirty_expire_centisecs 2>/dev/null
    echo 150 > /proc/sys/vm/watermark_scale_factor 2>/dev/null
    echo 32768 > /proc/sys/vm/min_free_kbytes 2>/dev/null

    # Tame aggressive OEM hybridswap thread to eliminate UI stutter and CPU burning
    if [ -f /sys/block/zram0/hybridswap_swapd_pause ]; then
        echo 1 > /sys/block/zram0/hybridswap_swapd_pause 2>/dev/null
    fi

    # 2. CPUFreq schedutil responsive cluster limits & low latency
    # Silver cluster (Policy 0: cores 0-3) - responsive baseline
    if [ -d "/sys/devices/system/cpu/cpufreq/policy0/schedutil" ]; then
        echo 500 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us 2>/dev/null
        echo 2000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us 2>/dev/null
        echo 1075200 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq 2>/dev/null
        echo 80 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load 2>/dev/null
        echo "80 1075200:85 1420800:90" > /sys/devices/system/cpu/cpufreq/policy0/schedutil/target_loads 2>/dev/null
        echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/rtg_boost_freq 2>/dev/null
        echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/pl 2>/dev/null
    fi

    # Gold cluster (Policy 4: cores 4-6) - instant boost for UI thread frames
    if [ -d "/sys/devices/system/cpu/cpufreq/policy4/schedutil" ]; then
        echo 500 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/up_rate_limit_us 2>/dev/null
        echo 3000 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us 2>/dev/null
        echo 1344000 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq 2>/dev/null
        echo 80 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_load 2>/dev/null
        echo "80 1344000:85 1862400:90" > /sys/devices/system/cpu/cpufreq/policy4/schedutil/target_loads 2>/dev/null
        echo 0 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/rtg_boost_freq 2>/dev/null
    fi

    # Prime core (Policy 7: core 7 @ 3.2GHz) - fast burst on demand
    if [ -d "/sys/devices/system/cpu/cpufreq/policy7/schedutil" ]; then
        echo 500 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/up_rate_limit_us 2>/dev/null
        echo 4000 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/down_rate_limit_us 2>/dev/null
        echo 1516800 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_freq 2>/dev/null
        echo 85 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_load 2>/dev/null
        echo "85 1632000:90 2419200:95" > /sys/devices/system/cpu/cpufreq/policy7/schedutil/target_loads 2>/dev/null
        echo 0 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/rtg_boost_freq 2>/dev/null
        echo 0 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/pl 2>/dev/null
    fi
    [ -w /sys/module/workqueue/parameters/power_efficient ] && echo N > /sys/module/workqueue/parameters/power_efficient 2>/dev/null

    # 3. Scheduler Latency Tuning - 4ms latency eliminates 120Hz frame stutters
    echo 4000000 > /proc/sys/kernel/sched_latency_ns          2>/dev/null
    echo 1000000 > /proc/sys/kernel/sched_min_granularity_ns  2>/dev/null
    echo 500000  > /proc/sys/kernel/sched_migration_cost_ns   2>/dev/null

    # 4. UFS / Block I/O Tuning - none/mq-deadline for zero queue latency
    for b in /sys/block/sd*/queue; do
        [ -d "$b" ] || continue
        echo none > "$b/scheduler" 2>/dev/null || echo mq-deadline > "$b/scheduler" 2>/dev/null || echo deadline > "$b/scheduler" 2>/dev/null
        echo 512      > "$b/read_ahead_kb" 2>/dev/null
        echo 128      > "$b/nr_requests"   2>/dev/null
        echo 0        > "$b/iostats"       2>/dev/null
        echo 0        > "$b/add_random"    2>/dev/null
    done
        echo 512      > "$b/read_ahead_kb" 2>/dev/null
        echo 128      > "$b/nr_requests"   2>/dev/null
        echo 0        > "$b/iostats"       2>/dev/null
        echo 0        > "$b/add_random"    2>/dev/null
    done

    # 5. Network Tuning
    echo bbr      > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    echo fq_codel > /proc/sys/net/core/default_qdisc          2>/dev/null

    # 6. Display Enhancement
    [ -d /sys/kernel/oplus_display ] && echo 1 > /sys/kernel/oplus_display/backlight_smooth 2>/dev/null

    # 7. Lock Developer Options & USB Debugging Permanently ON
    settings put global oplus_settings_developer_mode_auto_turn_off 0 2>/dev/null
    settings put secure oplus_settings_developer_mode_auto_turn_off 0 2>/dev/null
    settings put system oplus_settings_developer_mode_auto_turn_off 0 2>/dev/null
    settings put global oplus_customize_settings_developer_mode_auto_turn_off 0 2>/dev/null
    settings put global developer_mode_auto_turn_off 0 2>/dev/null
    settings put global development_settings_enabled 1 2>/dev/null
    settings put global adb_enabled 1 2>/dev/null
    resetprop -n persist.sys.development_settings_enabled 1 2>/dev/null
    resetprop -n persist.sys.all.developer.mode 1 2>/dev/null
    resetprop -n persist.sys.adb.support 1 2>/dev/null
    resetprop -n persist.oplus.debug.developer_mode 1 2>/dev/null

    # 7. Safeguard against modules disabling Developer Options / ADB on boot
    if [ -f /data/adb/brene/config.sh ]; then
        sed -i 's/config_developer_options=0/config_developer_options=1/g' /data/adb/brene/config.sh 2>/dev/null
        sed -i 's/config_usb_debugging=0/config_usb_debugging=1/g' /data/adb/brene/config.sh 2>/dev/null
    fi
    if [ -d /data/adb/specter/config/val ]; then
        echo 0 > /data/adb/specter/config/val/toggle_adb_disabler.val 2>/dev/null
        echo 0 > /data/adb/specter/config/val/toggle_adb_disabler_dev_options.val 2>/dev/null
        echo 0 > /data/adb/specter/config/val/toggle_adb_disabler_usb_debug.val 2>/dev/null
        echo 0 > /data/adb/specter/config/val/toggle_adb_disabler_oem_unlock.val 2>/dev/null
    fi

    # 8. HMA OSS Settings & Permission Persistence
    # Prevent settings reverting on reboot due to root-owned imported SharedPreferences
    for pkg in org.mywalkb.hma icu.nullptr.hma cn.gekichou.hma com.hma.oss; do
        for pdir in "/data/data/$pkg" "/data/user/0/$pkg"; do
            [ -d "$pdir" ] || continue
            pkg_owner="$(stat -c '%u:%g' "$pdir" 2>/dev/null)"
            pkg_uid="$(echo "$pkg_owner" | cut -d: -f1)"
            if [ -n "$pkg_uid" ] && [ "$pkg_uid" -ge 10000 ] 2>/dev/null; then
                chown -R "$pkg_owner" "$pdir" 2>/dev/null
                chmod -R u+rwX,g+rX "$pdir" 2>/dev/null
                restorecon -RF "$pdir" 2>/dev/null
            fi
        done
    done
    if [ -d /data/adb/hma ]; then
        chmod -R 755 /data/adb/hma 2>/dev/null
        chmod 644 /data/adb/hma/* 2>/dev/null
    fi
}

# Run immediate baseline
apply_tuning

# Wait for boot completion in background to counter late vendor post_boot.sh writes
(
    i=0
    while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 120 ]; do
        sleep 2
        i=$((i + 1))
    done
    sleep 5
    apply_tuning
    sleep 10
    apply_tuning
    echo "=== $(date) mystic-tune completed successfully ==="
) &
