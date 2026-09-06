// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CustomVolumeHUD",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CustomVolumeHUD",
            targets: ["CustomVolumeHUD"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CustomVolumeHUD",
            dependencies: [],
            path: "Sources/CustomVolumeHUD"
        )
    ]
)
