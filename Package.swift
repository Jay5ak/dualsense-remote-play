// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DualSenseRemotePlay",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DualSenseRemotePlay", targets: ["DualSenseRemotePlay"])
    ],
    targets: [
        .executableTarget(
            name: "DualSenseRemotePlay",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
