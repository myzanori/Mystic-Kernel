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

    # Keep hybridswap swapd active for smooth background page reclamation
    [ -w /sys/module/hybridswap/parameters/hybridswap_swapd_pause ] && echo 0 > /sys/module/hybridswap/parameters/hybridswap_swapd_pause 2>/dev/null

    # 1. Memory Tuning (Balanced responsiveness profile - prevents kswapd thrashing & keeps hybridswap intact)
    echo 60 > /proc/sys/vm/swappiness 2>/dev/null
    [ -w /proc/sys/vm/direct_swappiness ] && echo 60 > /proc/sys/vm/direct_swappiness 2>/dev/null
    echo 50 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    echo 300 > /proc/sys/vm/dirty_expire_centisecs 2>/dev/null
    echo 100 > /proc/sys/vm/watermark_scale_factor 2>/dev/null
    echo 32768 > /proc/sys/vm/min_free_kbytes 2>/dev/null
    [ -w /proc/sys/vm/extra_free_kbytes ] && echo 0 > /proc/sys/vm/extra_free_kbytes 2>/dev/null

    # Multi-stream ZRAM compression matching Little CPU cores
    if [ -d /sys/block/zram0 ]; then
        [ -w /sys/block/zram0/max_comp_streams ] && echo 4 > /sys/block/zram0/max_comp_streams 2>/dev/null
    fi

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
    # WALT migration: enable responsive task upmigration to Gold/Prime cores for media decoding and file sharing
    echo 80  > /proc/sys/kernel/sched_group_upmigrate    2>/dev/null
    echo 65  > /proc/sys/kernel/sched_group_downmigrate  2>/dev/null
    echo 4000000 > /proc/sys/kernel/sched_latency_ns          2>/dev/null
    echo 1000000 > /proc/sys/kernel/sched_min_granularity_ns  2>/dev/null
    echo 500000  > /proc/sys/kernel/sched_migration_cost_ns   2>/dev/null

    # SchedTune EAS tuning: prioritize UI responsiveness and reduce jitter
    for st in /dev/stune; do
        [ -d "$st" ] || continue
        [ -w "$st/top-app/schedtune.boost" ] && echo 1 > "$st/top-app/schedtune.boost" 2>/dev/null
        [ -w "$st/top-app/schedtune.prefer_idle" ] && echo 1 > "$st/top-app/schedtune.prefer_idle" 2>/dev/null
        [ -w "$st/foreground/schedtune.prefer_idle" ] && echo 1 > "$st/foreground/schedtune.prefer_idle" 2>/dev/null
        [ -w "$st/background/schedtune.boost" ] && echo 0 > "$st/background/schedtune.boost" 2>/dev/null
        [ -w "$st/background/schedtune.prefer_idle" ] && echo 0 > "$st/background/schedtune.prefer_idle" 2>/dev/null
    done

    # 4. UFS Storage Low-Latency & Block I/O Tuning
    # Disable aggressive UFS link auto-hibernation to eliminate I/O wakeup lag in Gallery & Telegram file picker
    [ -w /sys/devices/platform/soc/1d84000.ufshc/auto_hibern8 ] && echo 0 > /sys/devices/platform/soc/1d84000.ufshc/auto_hibern8 2>/dev/null
    for b in /sys/block/sd*/queue; do
        [ -d "$b" ] || continue
        echo mq-deadline > "$b/scheduler" 2>/dev/null || echo deadline > "$b/scheduler" 2>/dev/null || echo none > "$b/scheduler" 2>/dev/null
        echo 128      > "$b/read_ahead_kb" 2>/dev/null
        echo 128      > "$b/nr_requests"   2>/dev/null
        echo 0        > "$b/iostats"       2>/dev/null
        echo 0        > "$b/add_random"    2>/dev/null
    done

    # 5. Network Stack & High-Speed Throughput Tuning
    # Use BBR congestion control with fallback to westwood or cubic
    echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo westwood > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo cubic > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    echo fq > /proc/sys/net/core/default_qdisc 2>/dev/null || echo fq_codel > /proc/sys/net/core/default_qdisc 2>/dev/null
    echo 3        > /proc/sys/net/ipv4/tcp_fastopen           2>/dev/null
    echo 1        > /proc/sys/net/ipv4/tcp_tw_reuse           2>/dev/null
    echo 2        > /proc/sys/net/ipv4/tcp_syn_retries        2>/dev/null
    echo 2        > /proc/sys/net/ipv4/tcp_synack_retries     2>/dev/null
    echo 8        > /proc/sys/net/ipv4/tcp_retries2           2>/dev/null
    echo 1        > /proc/sys/net/ipv4/tcp_window_scaling     2>/dev/null
    echo 16777216 > /proc/sys/net/core/rmem_max               2>/dev/null
    echo 16777216 > /proc/sys/net/core/wmem_max               2>/dev/null
    echo "4096 87380 16777216" > /proc/sys/net/ipv4/tcp_rmem 2>/dev/null
    echo "4096 65536 16777216" > /proc/sys/net/ipv4/tcp_wmem 2>/dev/null

    # 6. Display Enhancement, Ambient Light Sensor & Biometric Optical FOD Compatibility
    if [ -d /sys/kernel/oplus_display ]; then
        [ ! -e /sys/kernel/oppo_display ] && ln -sf /sys/kernel/oplus_display /sys/kernel/oppo_display 2>/dev/null
        chmod 0666 /sys/kernel/oplus_display/* 2>/dev/null
        chmod 0666 /sys/kernel/oppo_display/* 2>/dev/null
    fi
    # Backlight and sensor device nodes access for Light HAL and SensorService
    chmod 0666 /sys/class/backlight/*/brightness 2>/dev/null
    chmod 0666 /dev/sensors /dev/msm_dsps 2>/dev/null

    if [ -d /proc/touchpanel ]; then
        # Unlock high touch report rate and disable touch limiting for instant response
        # Note: Do NOT force fp_enable=1 statically; doing so blocks the under-display ambient light sensor (ALS) and breaks auto-brightness
        [ -w /proc/touchpanel/game_switch_enable ] && echo 1 > /proc/touchpanel/game_switch_enable 2>/dev/null
        [ -w /proc/touchpanel/oplus_tp_limit_enable ] && echo 0 > /proc/touchpanel/oplus_tp_limit_enable 2>/dev/null
        [ -w /proc/touchpanel/oplus_tp_direction ] && echo 0 > /proc/touchpanel/oplus_tp_direction 2>/dev/null
        [ -w /proc/touchpanel/double_tap_enable ] && echo 1 > /proc/touchpanel/double_tap_enable 2>/dev/null
        chmod 0666 /proc/touchpanel/* 2>/dev/null
    fi

    # Biometric character devices and persist calibration permissions
    chmod 0666 /dev/goodix_fp /dev/jiiov_fp /dev/esfp0 /dev/silead_fp /dev/qseecom 2>/dev/null
    chmod 0777 /mnt/vendor/persist/engineermode 2>/dev/null
    chmod 0666 /mnt/vendor/persist/engineermode/* 2>/dev/null

    # Inject permissive SELinux rules for vendor biometric services if supolicy or magiskpolicy is available
    if command -v supolicy >/dev/null 2>&1; then
        supolicy --live "permissive hal_fingerprint_oplus" 2>/dev/null
        supolicy --live "permissive hal_fingerprintpay_oplus" 2>/dev/null
        supolicy --live "allow hal_fingerprint_oplus device chr_file { read write open ioctl }" 2>/dev/null
        supolicy --live "allow hal_fingerprint_oplus unlabeled file { read write open getattr }" 2>/dev/null
    elif command -v magiskpolicy >/dev/null 2>&1; then
        magiskpolicy --live "permissive hal_fingerprint_oplus" 2>/dev/null
        magiskpolicy --live "permissive hal_fingerprintpay_oplus" 2>/dev/null
        magiskpolicy --live "allow hal_fingerprint_oplus device chr_file { read write open ioctl }" 2>/dev/null
        magiskpolicy --live "allow hal_fingerprint_oplus unlabeled file { read write open getattr }" 2>/dev/null
    fi

    # Satisfy Goodix optical fingerprint HAL and SurfaceFlinger screen group
    resetprop -n oplus.optical.goodix.fp 1 2>/dev/null
    resetprop -n persist.oplus.display.screen.widthgroup 1 2>/dev/null
    resetprop -n persist.oplus.display.screen.heightgroup 1 2>/dev/null

    # 7. Lock Developer Options, USB Debugging, and Seamless Network Handover Permanently ON
    if [ "$(getprop sys.boot_completed)" = "1" ]; then
        settings put --user current global oplus_settings_developer_mode_auto_turn_off 0 >/dev/null 2>&1 || true
        settings put --user current secure oplus_settings_developer_mode_auto_turn_off 0 >/dev/null 2>&1 || true
        settings put --user current system oplus_settings_developer_mode_auto_turn_off 0 >/dev/null 2>&1 || true
        settings put --user current global oplus_customize_settings_developer_mode_auto_turn_off 0 >/dev/null 2>&1 || true
        settings put --user current global developer_mode_auto_turn_off 0 >/dev/null 2>&1 || true
        settings put --user current global development_settings_enabled 1 >/dev/null 2>&1 || true
        settings put --user current global adb_enabled 1 >/dev/null 2>&1 || true
        settings put global mobile_data_always_on 1 >/dev/null 2>&1 || true
    fi
    resetprop -n persist.sys.development_settings_enabled 1 2>/dev/null
    resetprop -n persist.sys.all.developer.mode 1 2>/dev/null
    resetprop -n persist.sys.adb.support 1 2>/dev/null
    resetprop -n persist.oplus.debug.developer_mode 1 2>/dev/null
    resetprop -n persist.sys.mobile_data_always_on 1 2>/dev/null

    # Telephony and IMS carrier defaults to avoid vendor_init AVC denials
    resetprop -n persist.data.iwlan.enable 1 2>/dev/null
    resetprop -n persist.dbg.ims_volte_enable 1 2>/dev/null
    resetprop -n persist.radio.rat_on combine 2>/dev/null
    resetprop -n persist.radio.data_ltd_sys_ind 1 2>/dev/null
    resetprop -n persist.radio.data_con_rprt 1 2>/dev/null
    resetprop -n persist.radio.calls.on.ims 1 2>/dev/null

    # Silence OPLUS DCS and log feedback loops that trigger system_server broadcast timeouts
    resetprop -n persist.sys.assert.panic false 2>/dev/null
    resetprop -n persist.sys.oplus.dcs false 2>/dev/null
    resetprop -n persist.sys.log.feedback false 2>/dev/null

    # 8. Adreno 650 GPU Responsiveness & Thermal Step-Down Smoothing
    if [ -d /sys/class/kgsl/kgsl-3d0 ]; then
        [ -w /sys/class/kgsl/kgsl-3d0/default_pwrlevel ] && echo 2 > /sys/class/kgsl/kgsl-3d0/default_pwrlevel 2>/dev/null
        [ -w /sys/class/kgsl/kgsl-3d0/idle_timer ] && echo 64 > /sys/class/kgsl/kgsl-3d0/idle_timer 2>/dev/null
        [ -w /sys/class/kgsl/kgsl-3d0/devfreq/adreno_boost ] && echo 1 > /sys/class/kgsl/kgsl-3d0/devfreq/adreno_boost 2>/dev/null
        [ -w /sys/class/kgsl/kgsl-3d0/throttling ] && echo 0 > /sys/class/kgsl/kgsl-3d0/throttling 2>/dev/null
    fi

    # 9. Background Storage Maintenance & Gentle Sleep Wakelock Clamp
    for f in /sys/fs/f2fs/*/gc_urgent; do
        [ -w "$f" ] && echo 0 > "$f" 2>/dev/null
    done
    for wl in wlan_pno_wl qcom_rx_wakelock IPA_WS; do
        [ -w /sys/devices/virtual/misc/wake_gestures/wlan_rx_wake ] && echo 0 > /sys/devices/virtual/misc/wake_gestures/wlan_rx_wake 2>/dev/null
    done


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

    # Periodic background maintenance (idle fstrim & memory compaction every 6 hours)
    while true; do
        sleep 21600
        fstrim -v /data >/dev/null 2>&1 || true
        fstrim -v /cache >/dev/null 2>&1 || true
        [ -w /proc/sys/vm/compact_memory ] && echo 1 > /proc/sys/vm/compact_memory 2>/dev/null
    done
) &
