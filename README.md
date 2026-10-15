# DualSense Remote Play

A lightweight, native macOS menu bar utility built with **SwiftUI** for **macOS 13 or later**.

DualSense Remote Play automatically detects when your Sony **DualSense Wireless Controller** or **DualSense Edge Wireless Controller** is connected or disconnected (via Bluetooth or USB). When connected, it launches **PS Remote Play** automatically; when disconnected, it gracefully closes it.

---

## Features

- **Menu Bar Utility**: Runs cleanly in the menu bar with `MenuBarExtra` and no cluttering main window or Dock icon (`LSUIElement`).
- **DualSense & DualSense Edge Support**: Auto-detects standard DualSense and DualSense Edge controllers via Apple GameController and IOBluetooth APIs.
- **Accurate Battery Level**: Reads battery status directly from Apple's `GCController.battery` (`0...100%`) without guessing.
- **Charging Breathing Effect**: Gentle, fluid green pulsating breathing animation in the menu bar while charging (`batteryState == .charging`), implemented safely on `@MainActor` without freezing the menu bar.
- **Low Battery Notification (20%)**: Emits a system notification with default sound once the battery level drops to 20% or lower. Automatically resets when recharged or disconnected.
- **Dynamic Color Indicators**:
  - 🟢 **Green**: Controller connected and link active.
  - ⚪ **White / Primary**: Controller disconnected.
  - 🔴 **Red**: Link paused.
- **Pause link / Resume link**:
  - `Pause link`: Suspends monitoring, closes PS Remote Play, frees the controller for Steam or native Mac games, and turns the menu bar icon red.
  - `Resume link`: Restores monitoring and automatically reconnects to PS Remote Play.
  - Real-time reactive SwiftUI menu item toggle (`Link: Active — Pause link` ↔ `Link: Paused — Resume link`).
- **Duplicate Remote Play Prevention**: Verifies running instances before launching, preventing multiple instances or crashes if Remote Play is not installed.
- **macOS Tahoe Aesthetic**: Minimalist frosted glass controller icon with battery neon accents.
- **Notch-Friendly Menu Bar Layout**: Uses a compact native `MenuBarExtra` presentation so the controller icon and battery percentage fit naturally in the available menu bar space on MacBook Pro models with a notch. No separate notch overlay or private API is required.

---

## Requirements

- **macOS 13.0 (Ventura)** or later.
- Compatible with Apple Silicon (M1/M2/M3/M4) and Intel Macs.
- Sony DualSense or DualSense Edge Controller.
- [PS Remote Play](https://remoteplay.dl.playstation.net/remoteplay/lang/en/) for macOS installed.

---

## Installation

### Using the DMG

1. Download or build `build/DualSense-Remote-Play.dmg`.
2. Open the disk image.
3. Drag **DualSense Remote Play.app** into the **Applications** folder shortcut.
4. Launch **DualSense Remote Play** from Launchpad or `/Applications`.

### MacBook models with a notch

The app runs as a native menu bar utility and keeps its status icon and battery percentage in the normal macOS menu bar. On MacBook Pro models with a notch, macOS manages the available menu bar space automatically; the app does not draw over the notch or use private notch APIs.

---

## Building from Source

### Prerequisites
- macOS with Xcode Command Line Tools installed (`xcode-select --install`).

### Build Steps

1. Clone the repository and navigate to the project directory:
   ```bash
   cd DualSenseRemotePlay
   ```

2. Compile using Swift Package Manager:
   ```bash
   swift build
   ```

3. Build the release `.app` bundle:
   ```bash
   ./Scripts/build-app.sh
   ```
   The compiled bundle will be generated at `build/DualSense Remote Play.app`.

4. Build the disk image (`.dmg`):
   ```bash
   ./Scripts/create-dmg.sh
   ```
   The output disk image will be created at `build/DualSense-Remote-Play.dmg`.

---

## macOS Security & Gatekeeper ("App can't be opened")

Because this build is signed locally with an ad-hoc signature and not notarized through an Apple Developer account, macOS Gatekeeper may show a warning on first launch stating that the developer cannot be verified.

Follow these precise steps to allow the app to run:

1. **Attempt to open the app once**: Double-click `DualSense Remote Play.app`. macOS will display an alert saying the app is from an unidentified developer. Click **Cancel** or **Done**.
2. **Open System Settings**: Click the Apple menu () in the top-left corner and select **System Settings** (or **System Preferences**).
3. **Navigate to Privacy & Security**: Select **Privacy & Security** from the sidebar and scroll down to the **Security** section.
4. **Click "Open Anyway"**: You will see a message: *"DualSense Remote Play was blocked from use because it is not from an identified developer."* Click the **Open Anyway** button next to it.
5. **Confirm and open**: When prompted, enter your administrator password or use Touch ID, then click **Open**.

DualSense Remote Play will now start and appear in your menu bar. You will not need to repeat this procedure for future launches.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
