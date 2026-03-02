#!/bin/bash
#========================================================
# JX Monitor Test Runner
#========================================================
# Phase 1: Build matrix (all config x target combos)
# Phase 2: Functional tests (cpmsim only)
#========================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Phase 1: Build Matrix ---
echo "========================================"
echo "Phase 1: Build Matrix Verification"
echo "========================================"
"$SCRIPT_DIR/test-build-matrix.sh"
echo ""

# --- Phase 2: Functional Tests ---
echo "========================================"
echo "Phase 2: Functional Tests (cpmsim)"
echo "========================================"

# Build monitor hex for harness-based tests
echo "=== Building JX Monitor for cpmsim ==="
make -C "$PROJECT_DIR" clean hex CONFIG=config.mk.sim
echo ""

echo "=== Running tests ==="

total=0
passed=0
failed=0
failed_names=""

for test_file in "$SCRIPT_DIR"/test-*.exp; do
    test_name="$(basename "$test_file" .exp)"
    echo "--- $test_name ---"
    total=$((total + 1))

    if expect "$test_file"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        failed_names="$failed_names $test_name"
    fi
    echo ""
done

# --- Summary ---
echo "==================================="
echo "Results: $passed/$total test files passed"

if [ $failed -gt 0 ]; then
    echo "Failed:$failed_names"
    exit 1
fi

echo "All tests passed."
exit 0
