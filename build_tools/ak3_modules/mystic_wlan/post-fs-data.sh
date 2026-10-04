#!/system/bin/sh
MODDIR=${0%/*}

# Load WLAN driver early so cnss/wlan interface is present before network services
if ! lsmod | grep -q wlan; then
    insmod "$MODDIR/wlan.ko" 2>/dev/null
fi

# Set ZRAM compression algorithm to LZ4 early before swap fills
if [ -f /sys/block/zram0/comp_algorithm ]; then
    if ! grep -q '\[lz4\]' /sys/block/zram0/comp_algorithm; then
        swapoff /dev/block/zram0 2>/dev/null
        echo 1 > /sys/block/zram0/reset 2>/dev/null
        echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null
        swapon /dev/block/zram0 2>/dev/null
    fi
fi
