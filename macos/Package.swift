// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "USBNotifier",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "USBNotifier",
            path: "Sources/USBNotifier"
        ),
        .testTarget(
            name: "USBNotifierTests",
            dependencies: ["USBNotifier"],
            path: "Tests/USBNotifierTests"
        )
    ]
)
