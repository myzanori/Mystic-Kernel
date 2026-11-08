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
    # On ColorOS/OOS, align vbmeta.device_state with bootloader lock state.
    # On AOSP custom ROMs, keep vbmeta.device_state as unlocked so the optical fingerprint TEE TA can enroll/authenticate without OEM keystore signature rejection.
    if [ -n "$(getprop ro.build.version.oplusrom)" ]; then
        LOCKED="$(getprop ro.boot.flash.locked)"
        STATE="$(getprop ro.boot.verifiedbootstate)"
        if [ "$LOCKED" = "1" ] || [ "$STATE" = "green" ]; then
            resetprop -n ro.boot.vbmeta.device_state locked 2>/dev/null
            resetprop -n vendor.boot.vbmeta.device_state locked 2>/dev/null
        else
            resetprop -n ro.boot.vbmeta.device_state unlocked 2>/dev/null
            resetprop -n vendor.boot.vbmeta.device_state unlocked 2>/dev/null
        fi
    else
        # AOSP: optical fingerprint TA requires unlocked vbmeta.device_state
        resetprop -n ro.boot.vbmeta.device_state unlocked 2>/dev/null
        resetprop -n vendor.boot.vbmeta.device_state unlocked 2>/dev/null
    fi

    # Silence SELinux audit denial flood & DAMON reclaim background scanner
    [ -w /proc/fs/selinux/enable_audit ] && echo 0 > /proc/fs/selinux/enable_audit 2>/dev/null
    [ -w /sys/module/damon_reclaim/parameters/enabled ] && echo N > /sys/module/damon_reclaim/parameters/enabled 2>/dev/null

    # Enable Multi-Gen LRU (MGLRU) for lightweight page reclamation
    [ -w /sys/kernel/mm/lru_gen/enabled ] && echo y > /sys/kernel/mm/lru_gen/enabled 2>/dev/null

    # Pause aggressive background flash cycling by hybridswap swapd
    [ -w /sys/module/hybridswap/parameters/hybridswap_swapd_pause ] && echo 1 > /sys/module/hybridswap/parameters/hybridswap_swapd_pause 2>/dev/null

    # 1. Memory Tuning (Balanced responsiveness profile - prevents kswapd thrashing & keeps hybridswap intact)
    echo 60 > /proc/sys/vm/swappiness 2>/dev/null
    [ -w /proc/sys/vm/direct_swappiness ] && echo 60 > /proc/sys/vm/direct_swappiness 2>/dev/null
    echo 100 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    echo 300 > /proc/sys/vm/dirty_expire_centisecs 2>/dev/null
    echo 100 > /proc/sys/vm/watermark_scale_factor 2>/dev/null
    echo 32768 > /proc/sys/vm/min_free_kbytes 2>/dev/null
    [ -w /proc/sys/vm/extra_free_kbytes ] && echo 0 > /proc/sys/vm/extra_free_kbytes 2>/dev/null

    # 2. CPUFreq schedutil responsive cluster limits & low latency
    # Schedutil down_rate_limit_us=20000 eliminates frequency thrashing and saves power (LineageOS parity)
    # Silver cluster (Policy 0: cores 0-3) - responsive baseline & UI thread boost
    if [ -d "/sys/devices/system/cpu/cpufreq/policy0/schedutil" ]; then
        echo 500 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us 2>/dev/null
        echo 20000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us 2>/dev/null
        echo 1075200 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq 2>/dev/null
        echo 80 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load 2>/dev/null
        echo "80 1075200:85 1420800:90" > /sys/devices/system/cpu/cpufreq/policy0/schedutil/target_loads 2>/dev/null
        echo 1075200 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/rtg_boost_freq 2>/dev/null
        echo 1 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/pl 2>/dev/null
    fi

    # Gold cluster (Policy 4: cores 4-6) - instant boost for UI thread frames
    if [ -d "/sys/devices/system/cpu/cpufreq/policy4/schedutil" ]; then
        echo 500 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/up_rate_limit_us 2>/dev/null
        echo 20000 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us 2>/dev/null
        echo 1344000 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq 2>/dev/null
        echo 80 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_load 2>/dev/null
        echo "80 1344000:85 1862400:90" > /sys/devices/system/cpu/cpufreq/policy4/schedutil/target_loads 2>/dev/null
        echo 1344000 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/rtg_boost_freq 2>/dev/null
    fi

    # Prime core (Policy 7: core 7 @ 3.2GHz) - fast burst on demand
    if [ -d "/sys/devices/system/cpu/cpufreq/policy7/schedutil" ]; then
        echo 500 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/up_rate_limit_us 2>/dev/null
        echo 20000 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/down_rate_limit_us 2>/dev/null
        echo 1516800 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_freq 2>/dev/null
        echo 85 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_load 2>/dev/null
        echo "85 1632000:90 2419200:95" > /sys/devices/system/cpu/cpufreq/policy7/schedutil/target_loads 2>/dev/null
        echo 1516800 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/rtg_boost_freq 2>/dev/null
        echo 1 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/pl 2>/dev/null
    fi
    [ -w /sys/module/workqueue/parameters/power_efficient ] && echo Y > /sys/module/workqueue/parameters/power_efficient 2>/dev/null

    # 3. Scheduler Latency & Task Migration Tuning
    # WALT migration: keep minor tasks on efficient Silver cores until genuine sustained load requires Gold/Prime
    echo 100 > /proc/sys/kernel/sched_group_upmigrate    2>/dev/null
    echo 95  > /proc/sys/kernel/sched_group_downmigrate  2>/dev/null
    echo 4000000 > /proc/sys/kernel/sched_latency_ns          2>/dev/null
    echo 1000000 > /proc/sys/kernel/sched_min_granularity_ns  2>/dev/null
    echo 500000  > /proc/sys/kernel/sched_migration_cost_ns   2>/dev/null

    # 4. UFS Storage Auto-Hibernation & Block I/O Tuning
    [ -w /sys/devices/platform/soc/1d84000.ufshc/auto_hibern8 ] && echo 1 > /sys/devices/platform/soc/1d84000.ufshc/auto_hibern8 2>/dev/null
    [ -w /sys/devices/platform/soc/1d84000.ufshc/clkgate_enable ] && echo 1 > /sys/devices/platform/soc/1d84000.ufshc/clkgate_enable 2>/dev/null
    for b in /sys/block/sd*/queue; do
        [ -d "$b" ] || continue
        echo none > "$b/scheduler" 2>/dev/null || echo mq-deadline > "$b/scheduler" 2>/dev/null || echo deadline > "$b/scheduler" 2>/dev/null
        echo 512      > "$b/read_ahead_kb" 2>/dev/null
        echo 128      > "$b/nr_requests"   2>/dev/null
        echo 0        > "$b/iostats"       2>/dev/null
        echo 0        > "$b/add_random"    2>/dev/null
    done

    # 5. Network Tuning
    echo bbr      > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    echo fq_codel > /proc/sys/net/core/default_qdisc          2>/dev/null

    # 6. Display Enhancement & AOSP FOD Compatibility
    if [ -d /sys/kernel/oplus_display ]; then
        echo 1 > /sys/kernel/oplus_display/backlight_smooth 2>/dev/null
        [ ! -e /sys/kernel/oppo_display ] && ln -sf /sys/kernel/oplus_display /sys/kernel/oppo_display 2>/dev/null
        chmod 0666 /sys/kernel/oplus_display/notify_fppress 2>/dev/null
        chmod 0666 /sys/kernel/oplus_display/dimlayer_hbm 2>/dev/null
        chmod 0666 /sys/kernel/oplus_display/dimlayer_bl_en 2>/dev/null
        chmod 0666 /sys/kernel/oplus_display/hbm 2>/dev/null
        chmod 0666 /sys/kernel/oplus_display/power_status 2>/dev/null
    fi
    if [ -d /proc/touchpanel ]; then
        chmod 0666 /proc/touchpanel/coordinate 2>/dev/null
        chmod 0666 /proc/touchpanel/fp_enable 2>/dev/null
    fi

    # Satisfy Goodix optical fingerprint HAL and SurfaceFlinger screen group
    resetprop -n oplus.optical.goodix.fp 1 2>/dev/null
    resetprop -n persist.oplus.display.screen.widthgroup 1 2>/dev/null
    resetprop -n persist.oplus.display.screen.heightgroup 1 2>/dev/null

    # 7. Lock Developer Options & USB Debugging Permanently ON
    if [ "$(getprop sys.boot_completed)" = "1" ]; then
        settings put --user current global oplus_settings_developer_mode_auto_turn_off 0 >/dev/null 2>&1 || true
        settings put --user current secure oplus_settings_developer_mode_auto_turn_off 0 >/dev/null 2>&1 || true
        settings put --user current system oplus_settings_developer_mode_auto_turn_off 0 >/dev/null 2>&1 || true
        settings put --user current global oplus_customize_settings_developer_mode_auto_turn_off 0 >/dev/null 2>&1 || true
        settings put --user current global developer_mode_auto_turn_off 0 >/dev/null 2>&1 || true
        settings put --user current global development_settings_enabled 1 >/dev/null 2>&1 || true
        settings put --user current global adb_enabled 1 >/dev/null 2>&1 || true
    fi
    resetprop -n persist.sys.development_settings_enabled 1 2>/dev/null
    resetprop -n persist.sys.all.developer.mode 1 2>/dev/null
    resetprop -n persist.sys.adb.support 1 2>/dev/null
    resetprop -n persist.oplus.debug.developer_mode 1 2>/dev/null


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
