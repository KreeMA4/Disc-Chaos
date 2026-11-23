#!/usr/bin/env bash
# Installs (if missing) everything needed to export DISC CHAOS for Android headlessly:
#   Godot editor + matching export templates, OpenJDK 17, Android SDK (cmdline-tools,
#   platform-tools, build-tools 35.0.1, platform android-35), a debug keystore,
#   and Godot editor settings pointing at all of it.
# Everything is idempotent. Override locations with env vars below.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
GODOT_FLAVOR="${GODOT_FLAVOR:-stable}"
TOOLS_DIR="${TOOLS_DIR:-$HOME/.discchaos-toolchain}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$TOOLS_DIR/android-sdk}"
CMDLINE_TOOLS_ZIP="${CMDLINE_TOOLS_ZIP:-commandlinetools-linux-16111833_latest.zip}"
GODOT_BIN="${GODOT_BIN:-$TOOLS_DIR/godot/Godot_v${GODOT_VERSION}-${GODOT_FLAVOR}_linux.x86_64}"
KEYSTORE="${KEYSTORE:-$TOOLS_DIR/debug.keystore}"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_FLAVOR}"
# Official mirror used by godotengine.org/download (redirects to the release object store).
# GitHub release assets are used as a fallback.
GODOT_DL="https://downloads.godotengine.org/?version=${GODOT_VERSION}&flavor=${GODOT_FLAVOR}&slug="
GODOT_GH="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_FLAVOR}/"

mkdir -p "$TOOLS_DIR"
fetch() { # fetch <slug> <out>
  local slug="$1" out="$2"
  curl -fsSL --retry 4 -o "$out" "${GODOT_DL}${slug}" || \
  curl -fsSL --retry 4 -o "$out" "${GODOT_GH}Godot_v${GODOT_VERSION}-${GODOT_FLAVOR}_${slug}"
}

# ---- Godot editor ----
if [ ! -x "$GODOT_BIN" ]; then
  echo ">> Downloading Godot ${GODOT_VERSION}"
  mkdir -p "$TOOLS_DIR/godot"
  fetch "linux.x86_64.zip" "$TOOLS_DIR/godot/godot.zip"
  unzip -q -o "$TOOLS_DIR/godot/godot.zip" -d "$TOOLS_DIR/godot"
  rm -f "$TOOLS_DIR/godot/godot.zip"
  chmod +x "$GODOT_BIN"
fi

# ---- Export templates ----
if [ ! -f "$TEMPLATE_DIR/android_debug.apk" ]; then
  echo ">> Downloading export templates"
  mkdir -p "$TEMPLATE_DIR"
  fetch "export_templates.tpz" "$TOOLS_DIR/templates.tpz"
  tmp="$(mktemp -d)"
  unzip -q -o "$TOOLS_DIR/templates.tpz" -d "$tmp"
  cp -r "$tmp"/templates/* "$TEMPLATE_DIR/"
  rm -rf "$tmp" "$TOOLS_DIR/templates.tpz"
fi

# ---- JDK 17 (Godot 4.x Android docs) ----
if [ -z "${JAVA_HOME:-}" ] || ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -q '"17'; then
  for c in /usr/lib/jvm/java-17-openjdk-amd64 /usr/lib/jvm/temurin-17-jdk-amd64 "$TOOLS_DIR/jdk17"; do
    [ -x "$c/bin/java" ] && JAVA_HOME="$c" && break
  done
fi
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/keytool" ]; then
  echo ">> Installing OpenJDK 17"
  if command -v apt-get >/dev/null && [ "$(id -u)" = 0 ]; then
    apt-get update -qq && apt-get install -y -qq openjdk-17-jdk-headless
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
  else
    curl -fsSL -o "$TOOLS_DIR/jdk.tgz" "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse"
    mkdir -p "$TOOLS_DIR/jdk17" && tar xzf "$TOOLS_DIR/jdk.tgz" -C "$TOOLS_DIR/jdk17" --strip-components=1
    rm -f "$TOOLS_DIR/jdk.tgz"; JAVA_HOME="$TOOLS_DIR/jdk17"
  fi
fi
export JAVA_HOME

# ---- Android SDK ----
SDKM="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKM" ]; then
  echo ">> Installing Android command-line tools"
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
  curl -fsSL --retry 4 -o "$TOOLS_DIR/clt.zip" "https://dl.google.com/android/repository/${CMDLINE_TOOLS_ZIP}"
  tmp="$(mktemp -d)"; unzip -q "$TOOLS_DIR/clt.zip" -d "$tmp"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"; mv "$tmp/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  rm -rf "$tmp" "$TOOLS_DIR/clt.zip"
fi
if [ ! -d "$ANDROID_SDK_ROOT/build-tools/35.0.1" ] || [ ! -d "$ANDROID_SDK_ROOT/platforms/android-35" ] || [ ! -d "$ANDROID_SDK_ROOT/platform-tools" ]; then
  echo ">> Installing Android SDK packages"
  yes | "$SDKM" --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null 2>&1 || true
  "$SDKM" --sdk_root="$ANDROID_SDK_ROOT" "platform-tools" "build-tools;35.0.1" "platforms;android-35" >/dev/null
fi

# ---- Debug keystore ----
if [ ! -f "$KEYSTORE" ]; then
  echo ">> Generating debug keystore"
  "$JAVA_HOME/bin/keytool" -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
    -keystore "$KEYSTORE" -storepass android -dname "CN=Android Debug,O=Android,C=US" \
    -validity 9999 -deststoretype pkcs12 >/dev/null 2>&1
fi

# ---- Godot editor settings (written by script, no GUI needed) ----
MAJMIN="$(echo "$GODOT_VERSION" | cut -d. -f1,2)"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$CFG_DIR"
cat > "$CFG_DIR/editor_settings-${MAJMIN}.tres" <<EOT
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "$JAVA_HOME"
export/android/android_sdk_path = "$ANDROID_SDK_ROOT"
export/android/debug_keystore = "$KEYSTORE"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/shutdown_adb_on_exit = true
EOT

cat > "$TOOLS_DIR/env.sh" <<EOT
export GODOT_BIN="$GODOT_BIN"
export JAVA_HOME="$JAVA_HOME"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
EOT
echo ">> Toolchain ready: $TOOLS_DIR (source $TOOLS_DIR/env.sh)"
