### Highlights & Key Improvements

• <b>Bootloop & Network Fix:</b> Restored real 4.19 release reporting for netd to prevent eBPF fatal aborts across OxygenOS and restored PM8009 PMIC on OnePlus 8 (instantnoodle) camera subsystems.
• <b>Thermal & Battery Optimization:</b> Rebalanced schedutil rate limits (10ms down-rate decay) and WALT migration thresholds (95/85), disabled predictive load (pl=0), restored 300MHz deep idle step on Little cores, and disabled always-on mobile data on Wi-Fi to eliminate idle battery drain and heating.
• <b>Auto-Brightness Restored:</b> Unblocked the under-display ambient light sensor to allow continuous ambient lux tracking and seamless adaptive brightness transitions.
• <b>Gallery & Telegram Stutter Fixed:</b> Eliminated UFS link auto-hibernation delays and optimized VFS cache retention (<code>vfs_cache_pressure=50</code>) for instant photo browsing and attachment sharing.
• <b>SchedTune EAS Optimization:</b> Enabled prefer-idle placement and instant latency boost for foreground UI rendering threads to eliminate frame drops.
• <b>TCP BBR & Network Acceleration:</b> Enabled Google BBR congestion control, Fair Queueing (FQ), and expanded 16MB socket buffers for high-speed 5G/Wi-Fi 6 downloads.
• <b>240Hz Touch Sampling:</b> Uncapped touch panel throttling and enabled responsive game-mode touch polling for ultra-low input latency.
• <b>Multi-Stream ZRAM:</b> Configured 4 parallel compression streams matching Little CPU cores for smooth multitasking without thread serialization.
• <b>Adreno 650 DevFreq Boost:</b> Realigned initial wakeup clock to OEM level 2 (~490MHz) and enabled dynamic frequency boosting for consistent 120Hz frame pacing.
• <b>Idle Maintenance Daemon:</b> Automated periodic flash storage trim (<code>fstrim</code>) and deep sleep memory compaction to maintain zero file fragmentation.
• <b>Root & System Security:</b> Upstreamed KernelSU NoMount v2.3.0 (Driver Protocol v23) and SUSFS v2.4.0.
• <b>Background Telemetry Cleaned:</b> Suppressed runaway OPLUS DCS telemetry broadcast timeout ANRs on screen state toggles.
