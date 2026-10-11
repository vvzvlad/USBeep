// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "USBeep",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "USBeep",
            path: "Sources/USBeep"
        ),
        .testTarget(
            name: "USBeepTests",
            dependencies: ["USBeep"],
            path: "Tests/USBeepTests"
        )
    ]
)
