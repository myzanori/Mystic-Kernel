#!/system/bin/sh
# ==============================================================================
# Mystic Kernel — runtime tuning & stability daemon
# ==============================================================================

LOG=/data/adb/mystic-tune.log
exec >> "$LOG" 2>&1
echo "=== $(date) mystic-tune start (uptime $(cut -d. -f1 /proc/uptime 2>/dev/null)s) ==="

# Align security patch level to prevent "Internal Problem" warning dialog
V_PATCH="$(getprop ro.vendor.build.security_patch)"
if [ -n "$V_PATCH" ] && [ "$(getprop ro.build.version.security_patch)" != "$V_PATCH" ]; then
    resetprop -n ro.build.version.security_patch "$V_PATCH" 2>/dev/null
fi

apply_tuning() {
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

    # 2. CPUFreq schedutil anti-flap rate limits & Power-Efficient Workqueues
    for p in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -d "$p/schedutil" ] || continue
        echo 500  > "$p/schedutil/up_rate_limit_us"   2>/dev/null
        echo 2000 > "$p/schedutil/down_rate_limit_us" 2>/dev/null
    done
    echo Y > /sys/module/workqueue/parameters/power_efficient 2>/dev/null

    # 3. Scheduler Latency Tuning (v1.0.35 stable profile - prevents ANRs & saves battery)
    echo 8000000 > /proc/sys/kernel/sched_latency_ns          2>/dev/null
    echo 2000000 > /proc/sys/kernel/sched_min_granularity_ns  2>/dev/null
    echo 500000  > /proc/sys/kernel/sched_migration_cost_ns   2>/dev/null

    # 4. UFS / Block I/O Tuning
    for b in /sys/block/sd*/queue; do
        [ -d "$b" ] || continue
        echo bfq > "$b/scheduler"          2>/dev/null || echo deadline > "$b/scheduler" 2>/dev/null || echo noop > "$b/scheduler" 2>/dev/null
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
