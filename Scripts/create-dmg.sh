#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/Scripts/build-app.sh"
hdiutil create -volname "DualSense Remote Play" -srcfolder "$ROOT/build/DualSense Remote Play.app" -ov -format UDZO "$ROOT/build/DualSense-Remote-Play.dmg"
echo "DMG creada: $ROOT/build/DualSense-Remote-Play.dmg"
