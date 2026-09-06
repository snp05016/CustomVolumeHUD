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
        ),
        .library(
            name: "CustomVolumeHUDLib",
            targets: ["CustomVolumeHUDLib"]
        )
    ],
    targets: [
        .target(
            name: "CustomVolumeHUDLib",
            dependencies: [],
            path: "Sources/CustomVolumeHUDLib",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "CustomVolumeHUD",
            dependencies: ["CustomVolumeHUDLib"],
            path: "Sources/CustomVolumeHUD"
        ),
        .testTarget(
            name: "CustomVolumeHUDTests",
            dependencies: ["CustomVolumeHUDLib"],
            path: "Tests/CustomVolumeHUDTests"
        )
    ]
)
