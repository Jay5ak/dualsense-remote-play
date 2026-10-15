#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "==> Running build-app.sh first..."
bash "${SCRIPT_DIR}/build-app.sh"

BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="DualSense Remote Play.app"
APP_PATH="${BUILD_DIR}/${APP_NAME}"
DMG_NAME="DualSense-Remote-Play.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
VOLUME_NAME="DualSense Remote Play"
STAGING_DIR="${BUILD_DIR}/dmg_staging"

if [ ! -d "${APP_PATH}" ]; then
    echo "Error: Application bundle not found at ${APP_PATH}"
    exit 1
fi

echo "==> Preparing DMG staging area..."
rm -rf "${STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"

echo "==> Copying ${APP_NAME} to staging area..."
cp -R "${APP_PATH}" "${STAGING_DIR}/"

echo "==> Creating /Applications symlink..."
ln -s /Applications "${STAGING_DIR}/Applications"

echo "==> Creating disk image ${DMG_PATH}..."
hdiutil create -volname "${VOLUME_NAME}" \
               -srcfolder "${STAGING_DIR}" \
               -ov \
               -format UDZO \
               "${DMG_PATH}"

echo "==> Cleaning up staging directory..."
rm -rf "${STAGING_DIR}"

echo "==> Disk image created successfully at ${DMG_PATH}"
