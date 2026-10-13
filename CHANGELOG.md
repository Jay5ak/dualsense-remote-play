# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-10-12

### Added
- macOS menu bar application.
- Bluetooth detection for a paired DualSense Wireless Controller.
- Automatic launch of PS Remote Play when the controller connects.
- Automatic closure of PS Remote Play when the controller disconnects.
- Minimal controller status icon in the menu bar.
- Scripts to build the app and create a DMG installer.

- Changelog
All notable changes to DualSense Remote Play are documented here.
[1.1.0] - 2026-10-12
Added
- Show the connected controller's battery percentage beside the menu bar icon.
- Add a subtle breathing animation while the controller is charging.
- Add support for recognizing DualSense Edge Wireless Controller devices.
- Add a low-battery notification at 20% or below, with repeat alerts re-armed after the battery rises above 20%.
- Refresh the app icon with a minimal macOS-inspired design.
Notes
- Battery reporting depends on macOS exposing the controller's battery level through GameController.
- Low-battery notifications require macOS notification permission.
- This source package has not been built or runtime-tested on macOS in this environment. Verify the app and notification behavior on a Mac before publishing the release binary.
