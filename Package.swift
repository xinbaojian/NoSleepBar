// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NoSleepBar",
    platforms: [.macOS(.v11)],
    targets: [
        .executableTarget(
            name: "NoSleepBar",
            path: "Sources/NoSleepBar"
        )
    ]
)
