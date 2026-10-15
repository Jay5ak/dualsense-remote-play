// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DualSenseRemotePlay",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DualSenseRemotePlay",
            targets: ["DualSenseRemotePlay"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DualSenseRemotePlay",
            dependencies: [],
            path: "Sources/DualSenseRemotePlay",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("IOKit"),
                .linkedFramework("GameController"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
