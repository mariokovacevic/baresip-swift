// swift-tools-version: 6.0
import Foundation
import PackageDescription

let coreReleaseURL = "https://github.com/mariokovacevic/baresip-swift/releases/download/v1.0.0/BaresipKitCore.xcframework.zip"
let coreReleaseChecksum = "02297d35f2b2192ab254cc10b2b23c6bf0e8ad44a8bd73f3881135e6f9b83be6"

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let localCorePath = "Build/out/BaresipKitCore.xcframework"
let useLocalCore = FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent(localCorePath).path)
    || coreReleaseURL.isEmpty

let coreTarget: Target = useLocalCore
    ? .binaryTarget(name: "BaresipKitCore", path: localCorePath)
    : .binaryTarget(name: "BaresipKitCore", url: coreReleaseURL, checksum: coreReleaseChecksum)

let package = Package(
    name: "BaresipKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "BaresipKit", targets: ["BaresipKit"]),
        .library(name: "BaresipKitAudio", targets: ["BaresipKitAudio"]),
        .library(name: "BaresipKitVideo", targets: ["BaresipKitVideo"]),
        .library(name: "BaresipKitCallKit", targets: ["BaresipKitCallKit"]),
        .library(name: "BaresipKitPushKit", targets: ["BaresipKitPushKit"]),
    ],
    targets: [
        coreTarget,
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
            path: "Sources/BaresipKit"
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
            dependencies: [
                "BaresipKitCore", "BaresipKitBridge", "BaresipKit", "BaresipKitAudio",
                "BaresipKitVideo", "BaresipKitCallKit", "BaresipKitPushKit",
            ],
            path: "Tests/BaresipKitTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
