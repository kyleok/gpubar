// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GPUBar",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
    ],
    targets: [
        .executableTarget(
            name: "GPUBar",
            dependencies: ["Sparkle"],
            path: "Sources/GPUBar",
            exclude: ["Info.plist"]
        )
    ]
)
