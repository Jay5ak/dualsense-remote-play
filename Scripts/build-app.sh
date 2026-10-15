#!/usr/bin/env bash
set -euo pipefail

# Determine script and project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "==> Building DualSenseRemotePlay in release mode..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/DualSenseRemotePlay"

if [ ! -f "${BIN_PATH}" ]; then
    echo "Error: Binary not found at ${BIN_PATH}"
    exit 1
fi

APP_BUNDLE_NAME="Gemini DualSense Remote Play.app"
BUILD_DIR="${PROJECT_DIR}/build"
APP_DIR="${BUILD_DIR}/${APP_BUNDLE_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Creating .app bundle structure at ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "==> Copying executable..."
cp "${BIN_PATH}" "${MACOS_DIR}/DualSenseRemotePlay"
chmod +x "${MACOS_DIR}/DualSenseRemotePlay"

echo "==> Copying Info.plist..."
cp "${PROJECT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

echo "==> Copying AppIcon.icns..."
if [ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

echo "==> Validating Info.plist..."
plutil -lint "${CONTENTS_DIR}/Info.plist"

echo "==> Applying ad-hoc code signature..."
if command -v codesign &> /dev/null; then
    codesign --force --deep --sign - "${APP_DIR}"
    echo "Ad-hoc code signing completed successfully."
fi

echo "==> Build finished successfully: ${APP_DIR}"
