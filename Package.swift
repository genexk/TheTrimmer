// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TheTrimmer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "TheTrimmerCore",
            path: "TheTrimmerCore"
        ),
        .executableTarget(
            name: "TheTrimmer",
            dependencies: ["TheTrimmerCore"],
            path: "TheTrimmer"
        ),
        .executableTarget(
            name: "trimmer-cli",
            dependencies: [
                "TheTrimmerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "CLI"
        ),
        .testTarget(
            name: "TheTrimmerTests",
            dependencies: ["TheTrimmerCore"],
            path: "TheTrimmerTests"
        ),
    ]
)
