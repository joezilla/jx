#!/bin/bash
#========================================================
# JX Monitor - Build Matrix Verification
#========================================================
# Tests all 9 config x target combinations assemble
# successfully and produce valid Intel HEX output.
#========================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

configs=(config.mk.sim config.mk.mon config.mk.sio)
targets=(hex basic basic8k)
output_files=("build/jx.hex" "build/basic.hex" "build/basic8k.hex")

total=0
passed=0
failed=0
failed_names=""

echo "=== Build Matrix ==="

for config in "${configs[@]}"; do
    for i in "${!targets[@]}"; do
        target="${targets[$i]}"
        hex="${output_files[$i]}"
        combo="$config:$target"
        total=$((total + 1))

        printf "  %-30s " "$combo"

        # Build (clean first to avoid stale artifacts)
        if ! make -C "$PROJECT_DIR" clean "$target" CONFIG="$config" > /dev/null 2>&1; then
            echo "FAIL (build error)"
            failed=$((failed + 1))
            failed_names="$failed_names $combo"
            continue
        fi

        # Verify hex file exists and is non-empty
        hex_path="$PROJECT_DIR/$hex"
        if [ ! -s "$hex_path" ]; then
            echo "FAIL (missing or empty hex)"
            failed=$((failed + 1))
            failed_names="$failed_names $combo"
            continue
        fi

        # Verify file starts with ':' (Intel HEX format)
        first_char=$(head -c 1 "$hex_path")
        if [ "$first_char" != ":" ]; then
            echo "FAIL (not Intel HEX)"
            failed=$((failed + 1))
            failed_names="$failed_names $combo"
            continue
        fi

        echo "ok"
        passed=$((passed + 1))
    done
done

echo ""
echo "Build matrix: $passed/$total passed"

if [ $failed -gt 0 ]; then
    echo "Failed:$failed_names"
    exit 1
fi

echo "All build combinations passed."
exit 0
