// swift-tools-version: 5.9
import Foundation
import PackageDescription

let coreReleaseURL = ""
let coreReleaseChecksum = ""

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
            dependencies: ["BaresipKit", "BaresipKitVideo", "BaresipKitAudio"],
            path: "Tests/BaresipKitTests"
        ),
    ]
)
