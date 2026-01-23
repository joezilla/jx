#!/bin/bash
#========================================================
# JX Operating System - Multi-Configuration Builder
#========================================================
# Builds the system for all supported memory configurations
#
# Usage: ./scripts/build-all-configs.sh
#========================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "JX Multi-Configuration Build"
echo "========================================"

# Supported memory sizes
CONFIGS="32 48 64"

for SIZE in $CONFIGS; do
    echo ""
    echo "Building for ${SIZE}KB..."
    echo "----------------------------------------"

    # Create config-specific build directory
    mkdir -p "$PROJECT_DIR/build/${SIZE}k"

    # Build
    make -C "$PROJECT_DIR" MEM_SIZE=$SIZE BUILD_DIR="build/${SIZE}k" clean all

    echo "Done: build/${SIZE}k/"
done

echo ""
echo "========================================"
echo "All configurations built successfully!"
echo "========================================"
echo ""
echo "Output directories:"
for SIZE in $CONFIGS; do
    echo "  build/${SIZE}k/ - ${SIZE}KB configuration"
done
