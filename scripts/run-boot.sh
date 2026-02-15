#!/bin/bash
#========================================================
# JX Monitor - Boot Script
#========================================================
# Builds and runs the JX monitor in cpmsim.
#
# Usage: ./scripts/run-boot.sh
#========================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Build hex for cpmsim
echo "Building JX Monitor..."
make -C "$PROJECT_DIR" hex || {
    echo "ERROR: Build failed"
    exit 1
}

# Parse config
Z80PACK_DIR=$(grep '^Z80PACK_DIR' "$PROJECT_DIR/config.mk" | sed 's/.*= *//' | head -1)
SIMULATOR=$(grep '^SIMULATOR' "$PROJECT_DIR/config.mk" | sed 's/.*= *//' | sed "s|\$(Z80PACK_DIR)|$Z80PACK_DIR|")
SIMULATOR=$(eval echo "$SIMULATOR")

SYSTEM_BIN="$PROJECT_DIR/build/jx.hex"

if [ ! -x "$SIMULATOR" ]; then
    echo "ERROR: Simulator not found at: $SIMULATOR"
    exit 1
fi

echo "========================================"
echo "JX Monitor"
echo "========================================"
echo "Binary: $SYSTEM_BIN"
echo "Size:   $(ls -lh "$SYSTEM_BIN" | awk '{print $5}')"
echo "========================================"
echo ""

# Run
"$SIMULATOR" -8 -f 2 -m 00 -x "$SYSTEM_BIN"
