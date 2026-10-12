# DualSense Remote Play

A lightweight macOS menu bar app that detects a connected DualSense Wireless Controller over Bluetooth and manages PS Remote Play automatically.

## Features

- Detects a paired DualSense Wireless Controller over Bluetooth.
- Opens PS Remote Play when the controller connects.
- Closes PS Remote Play when the controller disconnects.
- Runs from the macOS menu bar without a regular app window.
- Displays a minimal controller status icon.

## Requirements

- macOS 13 or later.
- A DualSense Wireless Controller paired with your Mac over Bluetooth.
- [PS Remote Play for Mac](https://remoteplay.dl.playstation.net/remoteplay/lang/en/index.html).

## Installation

1. Visit the [latest GitHub Release](https://github.com/Jay5ak/dualsense-remote-play/releases/latest).
2. Download `DualSense-Remote-Play.dmg`.
3. Open the DMG and drag `DualSense Remote Play.app` into your Applications folder.
4. Launch the app and connect your paired DualSense controller.

**Security note:** The app is not currently notarized by Apple. macOS may display a security warning. Only run software you trust and have verified.

## Build from Source

Requirements: Xcode Command Line Tools or a compatible Swift toolchain.

```sh
git clone https://github.com/Jay5ak/dualsense-remote-play.git
cd dualsense-remote-play
./Scripts/build-app.sh
```

To create a DMG:

```sh
./Scripts/create-dmg.sh
```

The DMG is generated at `build/DualSense-Remote-Play.dmg`.

## Usage

1. Install and configure PS Remote Play.
2. Pair your DualSense controller in **System Settings → Bluetooth**.
3. Launch DualSense Remote Play.
4. Connect your controller. The app checks the Bluetooth connection periodically and opens PS Remote Play when it detects a new connection.
5. Disconnect the controller to trigger the app's disconnect behavior.

The app runs from the menu bar. It does not provide a regular main window or a login-at-startup toggle.

## Limitations

- The app relies on macOS Bluetooth device detection.
- PS Remote Play must be installed separately.
- Behavior may vary with macOS versions and changes to PS Remote Play.
- This is an independent community project, not affiliated with or endorsed by Sony Interactive Entertainment.

## Contributing

Bug reports, suggestions, and pull requests are welcome. When reporting an issue, include your macOS version and steps to reproduce it.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.