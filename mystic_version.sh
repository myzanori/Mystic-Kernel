#!/usr/bin/env bash
# Mystic Kernel — versioning
# Single source of truth for Mystic Kernel branding
MYSTIC_BASE="1.0"
MYSTIC_BUILD_OVERRIDE="56"

_last_tag="$(git describe --tags --abbrev=0 --match 'mystic-*' 2>/dev/null || true)"
if [ -n "$_last_tag" ]; then
	MYSTIC_BUILD="$(git rev-list --count "${_last_tag}..HEAD" 2>/dev/null || echo 0)"
	_tag_num="$(echo "$_last_tag" | sed 's/.*\.//')"
	MYSTIC_BUILD="$(( _tag_num + MYSTIC_BUILD ))"
else
	MYSTIC_BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
fi

if ! git diff-index --quiet HEAD -- 2>/dev/null; then
	MYSTIC_BUILD="$((MYSTIC_BUILD + 1))"
fi

[ "$MYSTIC_BUILD" = "0" ] && MYSTIC_BUILD=1
[ -n "${MYSTIC_BUILD_OVERRIDE:-}" ] && MYSTIC_BUILD="$MYSTIC_BUILD_OVERRIDE"

export MYSTIC_NAME="Mystic Kernel"
export MYSTIC_AUTHOR="myzanori"
export MYSTIC_DEVICE="Kona"
export MYSTIC_PLATFORM="Kona"
export MYSTIC_ROM="OOS11-14"
export MYSTIC_VERSION="${MYSTIC_BASE}.${MYSTIC_BUILD}"
export MYSTIC_FLAVOUR="ReSukiSU_SUSFS"

export MYSTIC_PREFIX="Mystic_${MYSTIC_DEVICE}_${MYSTIC_ROM}_v${MYSTIC_VERSION}"
export MYSTIC_UNIFIED_PREFIX="Mystic_Kona_${MYSTIC_ROM}_v${MYSTIC_VERSION}"
export MYSTIC_LOCALVERSION="-perf-Mystic-Kona-myzanori-OOS11-14-v${MYSTIC_VERSION}"

echo "Mystic Kernel Branding Loaded: $MYSTIC_PREFIX (LOCALVERSION: $MYSTIC_LOCALVERSION)"
