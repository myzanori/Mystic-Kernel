#!/system/bin/sh
# Mystic Kernel runtime tuning

# Apply I/O tuning to all UFS block devices
for b in /sys/block/sd*/queue; do
    [ -d "$b" ] || continue
    echo "deadline" > "$b/scheduler" 2>/dev/null || echo "noop" > "$b/scheduler" 2>/dev/null
    echo 512 > "$b/read_ahead_kb" 2>/dev/null
    echo 128 > "$b/nr_requests" 2>/dev/null
done

# Network Tuning
echo "bbr"       > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
echo "fq_codel"  > /proc/sys/net/core/default_qdisc          2>/dev/null

# Memory Tuning
echo 100 > /proc/sys/vm/swappiness         2>/dev/null
echo 100 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
echo 60  > /proc/sys/vm/dirty_expire_centisecs 2>/dev/null

# Scheduler Latency Tuning
echo 8000000 > /proc/sys/kernel/sched_latency_ns          2>/dev/null
echo 2000000 > /proc/sys/kernel/sched_min_granularity_ns  2>/dev/null
echo 500000  > /proc/sys/kernel/sched_migration_cost_ns   2>/dev/null
