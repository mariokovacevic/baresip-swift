// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BaresipKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "BaresipKit", targets: ["BaresipKit"]),
        .library(name: "BaresipKitAudio", targets: ["BaresipKitAudio"]),
        .library(name: "BaresipKitVideo", targets: ["BaresipKitVideo"]),
        .library(name: "BaresipKitCallKit", targets: ["BaresipKitCallKit"]),
        .library(name: "BaresipKitPushKit", targets: ["BaresipKitPushKit"]),
    ],
    targets: [
        .binaryTarget(
            name: "BaresipKitCore",
            path: "Build/out/BaresipKitCore.xcframework"
        ),
        .target(
            name: "BaresipKitBridge",
            dependencies: ["BaresipKitCore"],
            path: "Sources/BaresipKitBridge",
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Security"),
                .linkedFramework("VideoToolbox"),
                .linkedLibrary("resolv"),
                .linkedLibrary("z"),
            ]
        ),
        .target(
            name: "BaresipKit",
            dependencies: ["BaresipKitCore", "BaresipKitBridge"],
            path: "Sources/BaresipKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "BaresipKitAudio",
            dependencies: ["BaresipKit"],
            path: "Sources/BaresipKitAudio"
        ),
        .target(
            name: "BaresipKitVideo",
            dependencies: ["BaresipKit"],
            path: "Sources/BaresipKitVideo"
        ),
        .target(
            name: "BaresipKitCallKit",
            dependencies: ["BaresipKit"],
            path: "Sources/BaresipKitCallKit"
        ),
        .target(
            name: "BaresipKitPushKit",
            dependencies: ["BaresipKit"],
            path: "Sources/BaresipKitPushKit"
        ),
        .testTarget(
            name: "BaresipKitTests",
            dependencies: ["BaresipKit"],
            path: "Tests/BaresipKitTests"
        ),
    ]
)
