#!/usr/bin/env bash
# Runs all headless test suites. Usage: tools/run_tests.sh [suite]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
SUITE="${1:-all}"
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1
out="$(timeout 1200 "$GODOT_BIN" --headless --path . --audio-driver Dummy res://tests/test_runner.tscn -- --suite="$SUITE" 2>&1)"
code=$?
echo "$out" | grep -vE "^\s*$|^Godot Engine"
if echo "$out" | grep -q "SCRIPT ERROR\|Parse Error"; then echo "!! script errors detected"; code=1; fi
exit $code
