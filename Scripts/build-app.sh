#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/DualSense Remote Play.app"

swift build -c release --package-path "$ROOT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/DualSenseRemotePlay" "$APP/Contents/MacOS/"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"
xattr -cr "$APP"
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP"

echo "App creada: $APP"
