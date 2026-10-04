#!/usr/bin/env bash
# Single source of truth for Mystic Kernel branding
export MYSTIC_NAME="Mystic Kernel"
export MYSTIC_AUTHOR="myzanori"
export MYSTIC_DEVICE="9R"
export MYSTIC_PLATFORM="Kona"
export MYSTIC_ROM="universal"
# Versioning Rule: Stable slow increments (1.0.xx format for iterative builds)
export MYSTIC_VERSION="1.0.02"
export MYSTIC_FLAVOUR="ReSukiSU_SUSFS"

# full artifact prefix
export MYSTIC_PREFIX="Mystic_${MYSTIC_DEVICE}_${MYSTIC_AUTHOR}_${MYSTIC_ROM}_v${MYSTIC_VERSION}"
export MYSTIC_UNIFIED_PREFIX="Mystic_Kona_${MYSTIC_AUTHOR}_${MYSTIC_ROM}_v${MYSTIC_VERSION}"
export MYSTIC_LOCALVERSION="-perf-Mystic-9R-myzanori-universal-v1.0.02"
echo "Mystic Kernel Branding Loaded: $MYSTIC_PREFIX (Unified: $MYSTIC_UNIFIED_PREFIX, LOCALVERSION: $MYSTIC_LOCALVERSION)"
