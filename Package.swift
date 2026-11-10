// swift-tools-version: 6.0
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
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "BaresipKit", targets: ["BaresipKit"]),
        .library(name: "BaresipKitAudio", targets: ["BaresipKitAudio"]),
        .library(name: "BaresipKitVideo", targets: ["BaresipKitVideo"]),
        .library(name: "BaresipKitCallKit", targets: ["BaresipKitCallKit"]),
        .library(name: "BaresipKitPushKit", targets: ["BaresipKitPushKit"]),
        .library(name: "BaresipKitSwiftUI", targets: ["BaresipKitSwiftUI"]),
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
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Security"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("VideoToolbox"),
                .linkedLibrary("resolv"),
                .linkedLibrary("z"),
            ]
        ),
        .target(
            name: "BaresipKit",
            dependencies: ["BaresipKitCore", "BaresipKitBridge"],
            path: "Sources/BaresipKit",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
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
        .target(
            name: "BaresipKitSwiftUI",
            dependencies: ["BaresipKit", "BaresipKitVideo"],
            path: "Sources/BaresipKitSwiftUI"
        ),
        .testTarget(
            name: "BaresipKitTests",
            dependencies: [
                "BaresipKitCore", "BaresipKitBridge", "BaresipKit", "BaresipKitAudio",
                "BaresipKitVideo", "BaresipKitCallKit", "BaresipKitPushKit", "BaresipKitSwiftUI",
            ],
            path: "Tests/BaresipKitTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
