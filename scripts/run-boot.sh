#!/bin/bash
#========================================================
# JX Operating System - Boot Test Runner
#========================================================
# Runs the BIOS boot sequence in the cpmsim simulator
#
# Usage: ./scripts/run-boot.sh
#========================================================

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source config values (parse from config.mk)
Z80PACK_DIR=$(grep '^Z80PACK_DIR' "$PROJECT_DIR/config.mk" | sed 's/.*= *//' | head -1)
SIMULATOR=$(grep '^SIMULATOR' "$PROJECT_DIR/config.mk" | sed 's/.*= *//' | sed "s|\$(Z80PACK_DIR)|$Z80PACK_DIR|")

# Expand any remaining variables
SIMULATOR=$(eval echo "$SIMULATOR")

# Build paths
BOOT_HEX="$PROJECT_DIR/build/test/boot.hex"
BIOS_HEX="$PROJECT_DIR/build/bios.hex"
COMBINED_HEX="$PROJECT_DIR/build/boot-combined.hex"

# Check simulator exists
if [ ! -x "$SIMULATOR" ]; then
    echo "ERROR: Simulator not found at: $SIMULATOR"
    echo "Please check Z80PACK_DIR in config.mk"
    exit 1
fi

# Build boot loader if needed
if [ ! -f "$BOOT_HEX" ]; then
    echo "Building boot loader..."
    make -C "$PROJECT_DIR" test-boot
fi

# Build BIOS in HEX format if needed
if [ ! -f "$BIOS_HEX" ] || [ "$PROJECT_DIR/src/bios/bios.asm" -nt "$BIOS_HEX" ]; then
    echo "Building BIOS..."
    make -C "$PROJECT_DIR" bios-hex
fi

# Combine HEX files (remove EOF record from boot, append BIOS)
# Boot HEX EOF record is :00000001FF
echo "Combining HEX files..."
grep -v ':00000001FF' "$BOOT_HEX" > "$COMBINED_HEX"
cat "$BIOS_HEX" >> "$COMBINED_HEX"

echo "========================================"
echo "Running JX Boot Sequence"
echo "Combined image: $COMBINED_HEX"
echo "Simulator: $SIMULATOR"
echo "========================================"
echo ""

# Ensure named pipes exist for auxiliary I/O
mkdir -p /tmp/.z80pack
[ -p /tmp/.z80pack/cpmsim.auxin ] || mkfifo /tmp/.z80pack/cpmsim.auxin
[ -p /tmp/.z80pack/cpmsim.auxout ] || mkfifo /tmp/.z80pack/cpmsim.auxout

# Start a background process to consume auxiliary output
# (required by cpmsim even though we don't use it)
cat /tmp/.z80pack/cpmsim.auxout >/dev/null 2>&1 &
AUXOUT_PID=$!

# Cleanup on exit
cleanup() {
    kill $AUXOUT_PID 2>/dev/null
}
trap cleanup EXIT

# Run the simulator
# -8 = 8080 mode
# -m 00 = initialize memory to 0
# -x = load and execute hex file
"$SIMULATOR" -8 -f 2 -m 00 -x "$COMBINED_HEX"
