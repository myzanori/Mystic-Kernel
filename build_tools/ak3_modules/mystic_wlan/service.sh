#!/system/bin/sh
MODDIR=${0%/*}

# Ensure WLAN module is loaded
if ! lsmod | grep -q wlan; then
    insmod "$MODDIR/wlan.ko" 2>/dev/null
fi

# Ensure ZRAM algorithm is LZ4
if [ -f /sys/block/zram0/comp_algorithm ]; then
    if ! grep -q '\[lz4\]' /sys/block/zram0/comp_algorithm; then
        swapoff /dev/block/zram0 2>/dev/null
        echo 1 > /sys/block/zram0/reset 2>/dev/null
        echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null
        swapon /dev/block/zram0 2>/dev/null
    fi
fi

# Wait for boot completion
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
sleep 3

# --- Mystic Runtime Jitter & Schedutil Optimizations ---
# Little Cores (0-3)
if [ -d /sys/devices/system/cpu/cpufreq/policy0/schedutil ]; then
    echo 500 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us 2>/dev/null
    echo 2000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us 2>/dev/null
fi

# Big Cores (4-6)
if [ -d /sys/devices/system/cpu/cpufreq/policy4/schedutil ]; then
    echo 500 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/up_rate_limit_us 2>/dev/null
    echo 2000 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us 2>/dev/null
fi

# Prime Core (7)
if [ -d /sys/devices/system/cpu/cpufreq/policy7/schedutil ]; then
    echo 500 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/up_rate_limit_us 2>/dev/null
    echo 4000 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/down_rate_limit_us 2>/dev/null
fi

# --- UFS Storage Latency & Throughput Optimizations ---
for dev in /sys/block/sd*; do
    [ -d "$dev/queue" ] || continue
    echo 128 > "$dev/queue/nr_requests" 2>/dev/null
    echo 512 > "$dev/queue/read_ahead_kb" 2>/dev/null
    echo 0 > "$dev/queue/iostats" 2>/dev/null
    echo 0 > "$dev/queue/add_random" 2>/dev/null
done

for dev in /sys/block/dm-*; do
    [ -d "$dev/queue" ] || continue
    echo 512 > "$dev/queue/read_ahead_kb" 2>/dev/null
    echo 0 > "$dev/queue/iostats" 2>/dev/null
done
