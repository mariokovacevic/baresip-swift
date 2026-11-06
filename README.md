# BaresipKit

Production-grade Swift wrapper for baresip: SIP, audio, video, ICE and CallKit-ready on iOS.

BaresipKit wraps the [baresip](https://github.com/baresip/baresip) user agent and the [libre](https://github.com/baresip/re) stack behind a small, stable C ABI and an idiomatic Swift API, packaged as a Swift Package with a binary XCFramework for the C core. License: BSD-3-Clause, matching baresip.

## Status

Phase 0 (feasibility) is complete and reviewed; Phase 1 (facade, bridge, Swift API) is in progress. Start with [`Docs/Phase0/README.md`](Docs/Phase0/README.md).

| Layer | Target | State |
|---|---|---|
| 1 | baresip + libre + OpenSSL + Opus C core, reproducible CMake build → XCFramework | verified on macOS for device arm64 and simulator arm64 |
| 2 | `BaresipKitCore` C ABI (`Core/`) | implemented: engine thread, accounts, registration, Contact parameters, calls, hold/resume, DTMF, mute, statistics; host test suite passes under ASan/UBSan |
| 3 | `BaresipKitBridge` | C helpers for event unions, module map |
| 4 | `BaresipKit` Swift API | written, awaiting first compile on macOS (`Docs/Phase1/macOS-verification-prompt.md`) |
| 5 | `BaresipKitAudio`, `BaresipKitCallKit`, `BaresipKitPushKit` | written, awaiting first compile; `BaresipKitVideo` holds types only until the video core lands |

## Repository layout

```
Build/        versions.env (pins), module-sets.env, build-xcframework.sh, cmake/ios.toolchain.cmake
Core/         BaresipKitCore: the C facade (include/baresip_kit.h, src/, CMakeLists.txt)
Docs/         Phase0 feasibility set, Phase1 macOS verification prompt
Patches/      small upstreamable diffs applied to the pinned baresip/libre sources
Sources/      BaresipKitBridge (C helpers), BaresipKit (Swift API), adapters
Tests/        Core (C tests, run_tests.sh), BaresipKitTests (XCTest)
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
