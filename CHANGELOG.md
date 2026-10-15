# Changelog

All notable changes to **DualSense Remote Play** will be documented in this file.

## [1.2.0] - 2026-10-15

### Added
- Gemini implementation adopted as the main application architecture.
- Explicit documentation for MacBook models with a notch and native menu bar behavior.
- Updated public version metadata and DMG build output.

## [1.0.0] - Initial Public Release

### Added
- **Menu Bar Utility**: Native macOS menu bar application powered by SwiftUI's `MenuBarExtra`, running without a main window or Dock icon (`LSUIElement`).
- **DualSense Support**: Automatic detection and connection handling for the Sony DualSense Wireless Controller via both Bluetooth and USB.
- **DualSense Edge Support**: Full compatibility and support for the Sony DualSense Edge Wireless Controller.
- **Real-Time Battery Percentage**: Accurate battery reporting reading directly from Apple's `GCController.battery` (`0% - 100%`) without guessing.
- **Charging Breathing Effect**: Smooth, lightweight breathing animation oscillating opacity between bright and dim green on `@MainActor` when the controller is actively charging.
- **Low Battery Notifications**: Proactive notification delivered via `UserNotifications` when the battery crosses the 20% threshold with the system default sound. State resets once recharged or upon controller disconnect.
- **Dynamic Color States**:
  - **Green**: Controller connected and link active.
  - **White**: Controller disconnected.
  - **Red**: Link paused.
- **Pause Link & Resume Link**: Quick toggle in the menu bar to temporarily suspend PS Remote Play automation, immediately terminating any active Remote Play session to free the controller for Steam, native Mac games, or emulators.
- **Duplicate Remote Play Prevention**: Reliable bundle identifier discovery (`com.playstation.RemotePlay`, `com.sie.psremoteplay`, `com.playstation.PSRemotePlay`, `com.playstation.remoteplay`) and `NSRunningApplication` checks to prevent opening duplicate instances.
- **macOS Tahoe-Inspired Icon**: Custom translucent frosted glass controller silhouette with battery green neon accent in `.icns`, `.iconset`, and high-resolution source PNG.
- **DMG & App Build Scripts**: Automated shell scripts `Scripts/build-app.sh` and `Scripts/create-dmg.sh` for generating release `.app` and `.dmg` distributables with ad-hoc signing.
- **Security & Non-Notarized Documentation**: Step-by-step instructions for bypassing macOS Gatekeeper on non-notarized ad-hoc builds.
