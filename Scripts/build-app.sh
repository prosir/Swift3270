#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/Swift3270.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
APP_VERSION="${SWIFT3270_VERSION:-0.1.1}"
APP_BUILD="${SWIFT3270_BUILD:-2}"

cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.build/cache" "$ROOT_DIR/.build/module-cache" "$ROOT_DIR/.build/icon-module-cache"
export SWIFTPM_HOME="$ROOT_DIR/.build/cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"

SWIFT_BUILD_ARGS=""
if [[ "${SWIFT3270_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
  SWIFT_BUILD_ARGS="--disable-sandbox"
fi

swift build ${SWIFT_BUILD_ARGS:+$SWIFT_BUILD_ARGS} -c release --cache-path "$ROOT_DIR/.build/cache"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/Swift3270" "$MACOS_DIR/Swift3270"
chmod +x "$MACOS_DIR/Swift3270"

CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/icon-module-cache" \
  swift "$ROOT_DIR/Scripts/generate-icon.swift" "$ROOT_DIR/.build"
if [[ -f "$ROOT_DIR/.build/Swift3270.icns" ]]; then
  cp "$ROOT_DIR/.build/Swift3270.icns" "$RESOURCES_DIR/Swift3270.icns"
elif ! iconutil --convert icns "$ROOT_DIR/.build/Swift3270.iconset" --output "$RESOURCES_DIR/Swift3270.icns"; then
  echo "Warning: could not generate Swift3270.icns; continuing without a custom app icon." >&2
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Swift3270</string>
  <key>CFBundleIdentifier</key>
  <string>com.swift3270.app</string>
  <key>CFBundleIconFile</key>
  <string>Swift3270</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Swift3270</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>__APP_VERSION__</string>
  <key>CFBundleVersion</key>
  <string>__APP_BUILD__</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

perl -0pi -e "s/__APP_VERSION__/$APP_VERSION/g; s/__APP_BUILD__/$APP_BUILD/g" "$CONTENTS_DIR/Info.plist"

echo "Created $APP_DIR"
echo "Open it with: open \"$APP_DIR\""
