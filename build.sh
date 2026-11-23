#!/usr/bin/env bash
# One-command reproducible Android export for DISC CHAOS.
#   ./build.sh            -> sets up toolchain if needed, imports, runs tests, exports signed debug APK
#   SKIP_TESTS=1 ./build.sh
# Output: build/DiscChaos-v<VERSION>.apk
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
VERSION="$(tr -d ' \n' < VERSION)"
CODE="$(echo "$VERSION" | awk -F. '{printf "%d", $1*1000 + $2*10 + ($3==""?0:$3)}')"
[ "$CODE" -lt 1 ] && CODE=1

bash tools/setup_toolchain.sh
# shellcheck disable=SC1091
source "${TOOLS_DIR:-$HOME/.discchaos-toolchain}/env.sh"

# Keep export preset version in sync with VERSION
sed -i -E "s/^version\/name=.*/version\/name=\"$VERSION\"/; s/^version\/code=.*/version\/code=$CODE/" export_presets.cfg
sed -i -E "s|^config/version=.*|config/version=\"$VERSION\"|" project.godot

echo ">> Importing project"
"$GODOT_BIN" --headless --path "$ROOT" --import 2>&1 | tee build_import.log | grep -E "ERROR|SCRIPT ERROR" && { echo "Import produced errors"; exit 1; } || true

if [ "${SKIP_TESTS:-0}" != "1" ]; then
  echo ">> Running tests"
  bash tools/run_tests.sh
fi

mkdir -p build
OUT="build/DiscChaos-v${VERSION}.apk"
echo ">> Exporting $OUT"
"$GODOT_BIN" --headless --path "$ROOT" --export-debug "Android" "$ROOT/$OUT" 2>&1 | tee build_export.log
[ -f "$OUT" ] || { echo "Export failed"; exit 1; }
"$ANDROID_SDK_ROOT/build-tools/35.0.1/apksigner" verify --print-certs "$OUT" | head -3 || true
ls -la "$OUT"
echo ">> Done: $OUT"
