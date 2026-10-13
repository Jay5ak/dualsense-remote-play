<p align="center">
  <img src="assets/logo.png" alt="DualSense Remote Play" width="180">
</p>

<h1 align="center">DualSense Remote Play</h1>

<p align="center">
  A lightweight macOS menu bar utility for managing PS Remote Play with DualSense and DualSense Edge controllers.
</p>

<p align="center">
  <a href="https://github.com/Jay5ak/dualsense-remote-play/releases/latest">Download the latest DMG</a>
  ·
  <a href="https://github.com/Jay5ak/dualsense-remote-play/issues">Report a bug</a>
</p>

## Features

- Detects DualSense and DualSense Edge controllers over Bluetooth or USB.
- Opens PS Remote Play when a supported controller connects.
- Avoids launching a second Remote Play instance when it is already open.
- Closes Remote Play when the controller disconnects.
- Shows the controller battery percentage in the menu bar.
- Sends a notification when the battery reaches 20% or less.
- Uses a green icon when connected and a white icon when disconnected.
- Shows a smooth green breathing effect while the controller is charging.
- Includes `Pause link` / `Resume link` for using the controller with Steam or native Mac games.
- Shows a red icon while the link is paused.
- Runs as a lightweight menu bar app without a traditional window.
- Includes a minimal macOS Tahoe-inspired app icon.

## Requirements

- macOS 13 or later.
- A DualSense or DualSense Edge controller.
- [PS Remote Play for Mac](https://remoteplay.dl.playstation.net/remoteplay/lang/en/index.html).

## Installation

1. Open the [latest release](https://github.com/Jay5ak/dualsense-remote-play/releases/latest).
2. Download `DualSense-Remote-Play.dmg`.
3. Open the DMG and drag `DualSense Remote Play.app` to Applications.
4. Pair or connect your controller in **System Settings → Bluetooth**.
5. Launch the app.

### macOS security warning

The app is currently distributed without Apple notarization. If macOS blocks it:

1. Try to open the app once.
2. Open **System Settings → Privacy & Security**.
3. Scroll to the security section.
4. Click **Open Anyway** for DualSense Remote Play.
5. Confirm the prompt and launch the app again.

This warning should disappear once releases are signed and notarized by Apple.

## Menu bar states

- **Green icon:** controller connected and link active.
- **White icon:** controller disconnected.
- **Red icon:** link paused; Remote Play supervision is stopped.
- **Green breathing icon:** controller is charging.
- **Pause link:** closes Remote Play and releases the controller for Steam or another Mac game.
- **Resume link:** restores controller monitoring and Remote Play behavior.

## Build from source

Requirements: Xcode Command Line Tools or a compatible Swift toolchain.

```sh
git clone https://github.com/Jay5ak/dualsense-remote-play.git
cd dualsense-remote-play
./Scripts/build-app.sh
./Scripts/create-dmg.sh
```

The source is open and includes the Swift code, build scripts, app icon resources, license, and changelog.
