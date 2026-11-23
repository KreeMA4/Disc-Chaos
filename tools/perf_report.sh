#!/usr/bin/env bash
# Renders levels under each graphics preset (software Vulkan via Xvfb) and records draw calls,
# primitives, active physics bodies, MultiMesh batches and memory. Output: tests/out/perf_report.md
# (FPS under the software rasterizer is meaningless; numbers are per-frame workload.)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
OUT=tests/out/perf_report.md
mkdir -p tests/out/perf
{
echo "| Level | Preset | max draw calls | max primitives | active bodies | MultiMesh batches | static items | VRAM MB | RAM MB |"
echo "|---|---|---|---|---|---|---|---|---|"
} > $OUT
for lv in ${LEVELS:-1 3 5 6}; do
  for pr in 0 1 2 3; do
    log=$(timeout 600 xvfb-run -a -s "-screen 0 1600x740x24" "$GODOT_BIN" --path . --audio-driver Dummy --resolution 1600x738 -- --dev-shots=$lv --preset=$pr --shots-out=res://tests/out/perf 2>&1)
    max=$(echo "$log" | grep PERFMAX | head -1)
    perf=$(echo "$log" | grep "^PERF " | head -1)
    d=$(echo "$max" | sed -E 's/.*draws=([0-9]+).*/\1/'); p=$(echo "$max" | sed -E 's/.*prims=([0-9]+).*/\1/')
    ab=$(echo "$perf" | sed -E 's/.*active_bodies=([0-9]+).*/\1/'); mm=$(echo "$perf" | sed -E 's/.*multimeshes=([0-9]+).*/\1/')
    si=$(echo "$perf" | sed -E 's/.*static_items=([0-9]+).*/\1/'); vr=$(echo "$perf" | sed -E 's/.*vram_mb=([0-9.]+).*/\1/'); rm=$(echo "$perf" | sed -E 's/.*static_mem_mb=([0-9.]+).*/\1/')
    name=$(sed -n "$((lv))p" <<< $'Bedroom\nLiving Room\nBasement\nAttic\nStore\nWarehouse')
    preset=$(sed -n "$((pr+1))p" <<< $'Low\nMedium\nHigh\nUltra')
    echo "| $lv $name | $preset | $d | $p | $ab | $mm | $si | $vr | $rm |" >> $OUT
    echo "level $lv preset $preset: draws $d prims $p"
  done
done
cat $OUT
