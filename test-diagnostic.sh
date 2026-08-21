#!/bin/bash
# Test script to run test_print.c instead of CCP for diagnostics

set -e

PROJECT_DIR="/Users/jtoppe/src/jx"
BUILD_DIR="$PROJECT_DIR/build"
SIMULATOR="$PROJECT_DIR/../z80pack/cpmsim/cpmsim"

# Build paths
BOOT_HEX="$BUILD_DIR/test/boot.hex"              # 0x0000
TEST_PRINT_HEX="$BUILD_DIR/examples/test_print.hex"  # 0x0100 (instead of CCP)
BDOS_HEX="$BUILD_DIR/bdos.hex"                   # 0xF500
BIOS_HEX="$BUILD_DIR/bios.hex"                   # 0xFD00
SYSTEM_HEX="$BUILD_DIR/test-system.hex"

echo "Building test system with test_print instead of CCP..."
echo "Components:"
echo "  Boot:       $BOOT_HEX"
echo "  Test Print: $TEST_PRINT_HEX (at 0x0100)"
echo "  BDOS:       $BDOS_HEX"
echo "  BIOS:       $BIOS_HEX"
echo ""

# Verify all components exist
for file in "$BOOT_HEX" "$TEST_PRINT_HEX" "$BDOS_HEX" "$BIOS_HEX"; do
    if [ ! -f "$file" ]; then
        echo "Error: Missing component: $file"
        exit 1
    fi
done

# Combine HEX files (remove EOF records except from last)
echo "Combining system image..."
{
    grep -v ':00000001FF' "$BOOT_HEX"
    grep -v ':00000001FF' "$TEST_PRINT_HEX"
    grep -v ':00000001FF' "$BDOS_HEX"
    cat "$BIOS_HEX"
} > "$SYSTEM_HEX"

echo "System image: $SYSTEM_HEX"
echo ""
echo "Starting simulator..."
echo "========================================"
echo ""

# Run simulator
"$SIMULATOR" -8 -f 2 -m 00 -x "$SYSTEM_HEX"
