#!/usr/bin/env bash
# Quick switch helper for Mystic Kernel development branches
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

usage() {
    echo "Usage: ./switch-branch.sh <target>"
    echo ""
    echo "Available targets:"
    echo "  main -> main (OxygenOS 11-14 Universal)"
    echo "  cos  -> cos  (ColorOS 15-17 Universal)"
    echo "  aosp -> aosp (AOSP / Custom ROMs)"
    echo ""
    echo "Current active branch:"
    git branch --show-current
    exit 1
}

TARGET="${1:-}"

case "$TARGET" in
    main|oos)
        git checkout main
        ;;
    cos|coloros)
        git checkout cos
        ;;
    aosp)
        git checkout aosp
        ;;
    *)
        usage
        ;;
esac

echo ""
echo ">> Successfully switched to branch: $(git branch --show-current)"
