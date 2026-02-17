#!/bin/bash
#========================================================
# JX Monitor Test Runner
#========================================================
# Builds with config.mk.sim, runs all test-*.exp files,
# reports pass/fail summary.
#========================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Build ---
echo "=== Building JX Monitor for cpmsim ==="
make -C "$PROJECT_DIR" clean hex CONFIG=config.mk.sim
echo ""

# --- Run tests ---
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
