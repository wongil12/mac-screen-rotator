// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "mac-screen-rotator",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ScreenRotationCore", targets: ["ScreenRotationCore"]),
        .executable(name: "screen-rotator-poc", targets: ["ScreenRotatorPoC"]),
        .executable(name: "screen-rotator-failsafe", targets: ["ScreenRotatorFailsafe"]),
        .executable(name: "MacScreenRotator", targets: ["MacScreenRotator"])
    ],
    targets: [
        .target(name: "ScreenRotationCore"),
        .executableTarget(
            name: "ScreenRotatorPoC",
            dependencies: ["ScreenRotationCore"]
        ),
        .executableTarget(
            name: "MacScreenRotator",
            dependencies: ["ScreenRotationCore"]
        ),
        .executableTarget(
            name: "ScreenRotatorFailsafe",
            dependencies: ["ScreenRotationCore"]
        ),
        .testTarget(
            name: "ScreenRotationCoreTests",
            dependencies: ["ScreenRotationCore"]
        )
    ]
)
