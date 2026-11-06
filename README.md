# BaresipKit

Production-grade Swift wrapper for baresip: SIP, audio, video, ICE and CallKit-ready on iOS.

BaresipKit wraps the [baresip](https://github.com/baresip/baresip) user agent and the [libre](https://github.com/baresip/re) stack behind a small, stable C ABI and an idiomatic Swift API, packaged as a Swift Package with a binary XCFramework for the C core. License: BSD-3-Clause, matching baresip.

## Status

Phase 0 (feasibility) is complete and waiting for review. No Swift API exists yet. Start with [`Docs/Phase0/README.md`](Docs/Phase0/README.md).

| Layer | Target | State |
|---|---|---|
| 1 | baresip + libre + OpenSSL + Opus C core, reproducible CMake build → XCFramework | build script written, host path verified, iOS slices need a macOS run |
| 2 | `BaresipKitCore` C ABI | header proposed (`Sources/BaresipKitCore/include/baresip_kit.h`), implementation pending review |
| 3 | `BaresipKitBridge` | pending |
| 4 | `BaresipKit` Swift API | pending |
| 5 | `BaresipKitAudio`, `BaresipKitVideo`, `BaresipKitCallKit`, `BaresipKitPushKit` | pending |

## Repository layout

```
Build/        versions.env (pins), module-sets.env, build-xcframework.sh, cmake/ios.toolchain.cmake
Docs/Phase0/  feasibility report, compatibility matrix, Contact parameter proof, C ABI conventions
Patches/      small upstreamable diffs applied to the pinned baresip/libre sources
Sources/      BaresipKitCore/include/baresip_kit.h (proposed ABI)
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
