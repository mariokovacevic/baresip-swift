# BaresipKit

Production-grade Swift wrapper for baresip: SIP, audio, video, ICE and CallKit-ready on iOS.

BaresipKit wraps the [baresip](https://github.com/baresip/baresip) user agent and the [libre](https://github.com/baresip/re) stack behind a small, stable C ABI and an idiomatic Swift API, packaged as a Swift Package with a binary XCFramework for the C core. License: BSD-3-Clause, matching baresip.

## Status

The SDK is feature complete for audio and video SIP calls and is in verification. Everything that can run on Linux is verified there under ASan/UBSan; Apple-only parts are verified on macOS in rounds (see the prompts in `Docs/Phase*/`).

| Layer | Target | State |
|---|---|---|
| 1 | baresip + libre + OpenSSL + Opus [+ libvpx] C core, reproducible CMake build → XCFramework | verified on macOS (device arm64, simulator arm64) and Linux host |
| 2 | `BaresipKitCore` C ABI (`Core/`) | engine, accounts, push Contact parameters, calls, hold/resume, DTMF, mute, statistics, ICE events, TLS pinning, video sinks and preview: host suite passes; `vidtoolbox` H.264 and `bskcapture` camera (`Core/src/apple`) await the next macOS round |
| 3 | `BaresipKitBridge` | verified on macOS |
| 4 | `BaresipKit` Swift API | compiled and tested on the simulator through the frame-sink API; video view additions await the next macOS round |
| 5 | `BaresipKitAudio`, `BaresipKitCallKit`, `BaresipKitPushKit`, `BaresipKitVideo` | compiled on the simulator; `BaresipVideoView` awaits the next macOS round |
| — | sample app, CI, Asterisk/coturn integration scaffold, fuzzing | written; sample app and CI await the next macOS round, integration suite needs Docker |

## Quick start

```swift
import BaresipKit

let engine = try BaresipEngine(configuration: BaresipConfiguration())
try await engine.start()
let account = try await engine.addAccount(BaresipAccountConfiguration(
    aor: "sip:1001@pbx.example.com",
    registrar: "sip:pbx.example.com:5061;transport=tls",
    authUser: "1001", authPassword: "secret"))
try await engine.register(accountID: account)
for await event in engine.events {
    if case .registration(_, .registered, _, _) = event {
        let call = try await engine.makeCall(destination: "sip:door@pbx.example.com", video: true)
        _ = call
        break
    }
}
```

## Documentation

Start at [`Docs/README.md`](Docs/README.md): architecture, building, the integration guide (accounts, push Contact parameters, calls, audio session, CallKit, PushKit, video, TLS, ICE) and limitations. The sample app is in `Examples/SampleApp`.

## Repository layout

```
Build/        versions.env (pins), module-sets.env, build-xcframework.sh, cmake/ios.toolchain.cmake
Core/         BaresipKitCore: the C facade (include/baresip_kit.h, src/, src/apple/, CMakeLists.txt)
Docs/         guides, Phase 0 feasibility set, macOS verification prompts
Examples/     SwiftUI sample app (xcodegen project)
Patches/      small upstreamable diffs applied to the pinned baresip/libre sources
Sources/      BaresipKitBridge (C helpers), BaresipKit (Swift API), adapters
Tests/        Core (C tests, run_tests.sh), BaresipKitTests (XCTest), Integration (Asterisk + coturn)
Tools/        ContactParameterProof: proof programs, fake registrar, trace verifier
```

## Building the C core

On macOS with Xcode installed:

```bash
Build/build-xcframework.sh
```

Produces `Build/out/BaresipKitCore.xcframework` (iOS device arm64 + iOS simulator arm64), a zip and its SPM checksum. `MODULE_SET=minimal|default|full` selects the baresip module set; `PLATFORM=host` builds natively for CI and sanitizer runs.

## Pinned upstream versions

libre v4.9.0, baresip v4.9.0, OpenSSL 3.5.9, Opus 1.6.1. See `Build/versions.env` and `DEPENDENCIES.md`.


## CallKit note

`BaresipCallKitConfiguration.localizedName` is deprecated and has no effect. `CXProviderConfiguration.localizedName` is read-only in current SDKs, so CallKit shows the application name from the app's `Info.plist`.
