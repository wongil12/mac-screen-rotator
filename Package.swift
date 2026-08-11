// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "mac-screen-rotator",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "screen-rotator-poc", targets: ["ScreenRotatorPoC"])
    ],
    targets: [
        .executableTarget(name: "ScreenRotatorPoC")
    ]
)
