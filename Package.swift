// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TheTrimmer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TheTrimmer",
            path: "TheTrimmer"
        ),
        .testTarget(
            name: "TheTrimmerTests",
            dependencies: ["TheTrimmer"],
            path: "TheTrimmerTests"
        ),
    ]
)
