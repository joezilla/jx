#!/bin/bash
#========================================================
# JX Operating System - Boot Test Runner
#========================================================
# Runs the complete JX system (CCP + BDOS + BIOS) in cpmsim
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
CCP_HEX="$PROJECT_DIR/build/ccp/ccp.hex"
BDOS_HEX="$PROJECT_DIR/build/bdos.hex"
BIOS_HEX="$PROJECT_DIR/build/bios.hex"
SYSTEM_HEX="$PROJECT_DIR/build/jx-system.hex"

# Check simulator exists
if [ ! -x "$SIMULATOR" ]; then
    echo "ERROR: Simulator not found at: $SIMULATOR"
    echo "Please check Z80PACK_DIR in config.mk"
    exit 1
fi

# Build system components if needed
echo "Building JX Operating System..."
make -C "$PROJECT_DIR" all >/dev/null 2>&1 || {
    echo "ERROR: Build failed"
    exit 1
}

# Build HEX versions of components
echo "Building Intel HEX files..."
make -C "$PROJECT_DIR" build/test/boot.hex >/dev/null 2>&1
make -C "$PROJECT_DIR" build/ccp/ccp.hex >/dev/null 2>&1
make -C "$PROJECT_DIR" build/bdos.hex >/dev/null 2>&1
make -C "$PROJECT_DIR" build/bios.hex >/dev/null 2>&1

# Combine HEX files (remove EOF records except from last file)
# Intel HEX EOF record is :00000001FF
# Load order: boot (0x0000) -> CCP (0x0100) -> BDOS (0xF500) -> BIOS (0xFD00)
echo "Combining system image..."
{
    grep -v ':00000001FF' "$BOOT_HEX"
    grep -v ':00000001FF' "$CCP_HEX"
    grep -v ':00000001FF' "$BDOS_HEX"
    cat "$BIOS_HEX"
} > "$SYSTEM_HEX"

echo "========================================"
echo "JX Operating System"
echo "========================================"
echo "Boot: $(ls -lh $BOOT_HEX | awk '{print $5}') @ 0x0000"
echo "CCP:  $(ls -lh $CCP_HEX | awk '{print $5}') @ 0x0100"
echo "BDOS: $(ls -lh $BDOS_HEX | awk '{print $5}') @ 0xF500"
echo "BIOS: $(ls -lh $BIOS_HEX | awk '{print $5}') @ 0xFD00"
echo "System: $SYSTEM_HEX"
echo "Simulator: $SIMULATOR"
echo "========================================"
echo ""
echo "Starting JX..."
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
# -f 2 = 2MHz CPU speed
# -m 00 = initialize memory to 0x00
# -x = load and execute Intel HEX file
"$SIMULATOR" -8 -f 2 -m 00 -x "$SYSTEM_HEX"
