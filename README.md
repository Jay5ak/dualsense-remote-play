<p align="center">
  <img src="assets/logo.png" alt="DualSense Remote Play" width="180">
</p>

<h1 align="center">DualSense Remote Play</h1>

<p align="center">
  Automatically manage PS Remote Play on macOS when your DualSense controller connects or disconnects over Bluetooth.
</p>

<p align="center">
  <a href="https://github.com/Jay5ak/dualsense-remote-play/releases/latest">Latest Release</a>
  ·
  <a href="https://github.com/Jay5ak/dualsense-remote-play/issues">Report a Bug</a>
</p>

## Features

- Detects a paired DualSense Wireless Controller over Bluetooth.
- Opens PS Remote Play when the controller connects.
- Closes PS Remote Play when the controller disconnects.
- Runs from the macOS menu bar without a traditional app window.
- Displays a minimal controller status indicator.
- Supports DualSense Edge controllers.
- Provides a `Pause link` / `Resume link` menu-bar toggle for using the controller with Steam or native Mac games.

## Requirements

- macOS 13 or later.
- A DualSense Wireless Controller paired with your Mac over Bluetooth.
- [PS Remote Play for Mac](https://remoteplay.dl.playstation.net/remoteplay/lang/en/index.html).

## Installation

1. Visit the [latest release](https://github.com/Jay5ak/dualsense-remote-play/releases/latest).
2. Download `DualSense-Remote-Play.dmg` when available.
3. Drag `DualSense Remote Play.app` into Applications.
4. Pair your controller in System Settings → Bluetooth.
5. Open the app and connect your controller.

> **Security note:** The app is not currently notarized by Apple. macOS may display a security warning.

If macOS blocks the app, open **System Settings → Privacy & Security**, scroll to the security section, and click **Open Anyway** for DualSense Remote Play. Confirm the prompt, then launch the app again. This is expected until the app is distributed with Apple notarization.

## Build from Source

Requirements: Xcode Command Line Tools or a compatible Swift toolchain.

```sh
git clone https://github.com/Jay5ak/dualsense-remote-play.git
cd dualsense-remote-play
./Scripts/build-app.sh
