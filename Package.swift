// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Aureus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Aureus", targets: ["AureusApp"])
    ],
    targets: [
        .executableTarget(
            name: "AureusApp",
            path: "Sources/AureusApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AureusAppTests",
            dependencies: ["AureusApp"],
            path: "Tests/AureusAppTests"
        )
    ]
)
