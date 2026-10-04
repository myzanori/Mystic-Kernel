#!/usr/bin/env bash
# Single source of truth for Mystic Kernel branding
export MYSTIC_NAME="Mystic Kernel"
export MYSTIC_AUTHOR="myzanori"
export MYSTIC_DEVICE="9R"
export MYSTIC_PLATFORM="Kona"
export MYSTIC_ROM="OOS14"
# Versioning Rule: Official OnePlus 9R release for OxygenOS 14
export MYSTIC_VERSION="1.0.30"
export MYSTIC_FLAVOUR="ReSukiSU_SUSFS"

# full artifact prefix
export MYSTIC_PREFIX="Mystic_${MYSTIC_DEVICE}_${MYSTIC_AUTHOR}_${MYSTIC_ROM}_v${MYSTIC_VERSION}"
export MYSTIC_UNIFIED_PREFIX="Mystic_9R_${MYSTIC_AUTHOR}_${MYSTIC_ROM}_v${MYSTIC_VERSION}"
export MYSTIC_LOCALVERSION="-perf-Mystic-9R-myzanori-OOS14-v1.0.30"
echo "Mystic Kernel Branding Loaded: $MYSTIC_PREFIX (LOCALVERSION: $MYSTIC_LOCALVERSION)"
