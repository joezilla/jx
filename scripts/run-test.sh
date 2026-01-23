#!/bin/bash
#========================================================
# JX Operating System - Test Runner Script
#========================================================
# Runs a test program in the cpmsim simulator
#
# Usage: ./scripts/run-test.sh <test-name>
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

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <test-name>"
    echo ""
    echo "Available tests:"
    ls -1 "$PROJECT_DIR/src/test/"*.asm 2>/dev/null | xargs -I {} basename {} .asm | sed 's/^/  /'
    exit 1
fi

TEST_NAME="$1"
TEST_HEX="$PROJECT_DIR/build/test/${TEST_NAME}.hex"

# Check if test hex file exists
if [ ! -f "$TEST_HEX" ]; then
    echo "Test file not found: $TEST_HEX"
    echo "Building..."
    make -C "$PROJECT_DIR" "test-${TEST_NAME}"
fi

# Check simulator exists
if [ ! -x "$SIMULATOR" ]; then
    echo "ERROR: Simulator not found at: $SIMULATOR"
    echo "Please check Z80PACK_DIR in config.mk"
    exit 1
fi

echo "========================================"
echo "Running test: $TEST_NAME"
echo "File: $TEST_HEX"
echo "Simulator: $SIMULATOR"
echo "========================================"
echo ""
echo "NOTE: The simulator runs interactively."
echo "      Press Ctrl-C to exit when done."
echo ""

# Run the simulator
# -8 = 8080 mode
# -m 00 = initialize memory to 0
# -x = load and execute hex file (includes load address)
exec "$SIMULATOR" -8 -m 00 -x "$TEST_HEX"
