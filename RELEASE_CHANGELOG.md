### Highlights & Key Improvements

• <b>Auto-Brightness Restored:</b> Unblocked the under-display ambient light sensor to allow continuous ambient lux tracking and seamless adaptive brightness transitions.
• <b>Gallery & Telegram Stutter Fixed:</b> Eliminated UFS link auto-hibernation delays and optimized VFS cache retention (<code>vfs_cache_pressure=50</code>) for instant photo browsing and attachment sharing.
• <b>240Hz Touch Sampling:</b> Uncapped touch panel throttling and enabled responsive game-mode touch polling for ultra-low input latency.
• <b>Multi-Stream ZRAM:</b> Configured 4 parallel compression streams matching Little CPU cores for smooth multitasking without thread serialization.
• <b>Adreno 650 DevFreq Boost:</b> Realigned initial wakeup clock to OEM level 2 (~490MHz) and enabled dynamic frequency boosting for consistent 120Hz frame pacing.
• <b>Root & System Security:</b> Upstreamed KernelSU NoMount v2.3.0 (Driver Protocol v23) and SUSFS v2.4.0.
• <b>Background Telemetry Cleaned:</b> Suppressed runaway OPLUS DCS telemetry broadcast timeout ANRs on screen state toggles.
