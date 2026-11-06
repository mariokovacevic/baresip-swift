# BaresipKit

Production-grade Swift wrapper for baresip: SIP, audio, video, ICE and CallKit-ready on iOS.

BaresipKit wraps the [baresip](https://github.com/baresip/baresip) user agent and the [libre](https://github.com/baresip/re) stack behind a small, stable C ABI and an idiomatic Swift API, packaged as a Swift Package with a binary XCFramework for the C core. License: BSD-3-Clause, matching baresip.

## Status

All three CI jobs pass on every push (`.github/workflows/ci.yml`):

| Job | What it verifies |
|---|---|
| macOS | XCFramework for iOS device arm64 and simulator arm64; host suite with ASan/UBSan incl. TLS pinning, ICE with ICE restart, VP8 and **H.264 via VideoToolbox** two-process video calls (capped bitrate, decoded frames delivered without a copy); Swift package build; **XCTest on an iPhone simulator** (engine lifecycle, contact parameters, video preview frames, `BaresipVideoView`, network events, audio options); **sample app build** |
| Linux | host build of the full module set; the same core suite under ASan/UBSan; libFuzzer over the facade parsers |
| Integration | Asterisk + coturn in Docker: TLS registration, echo calls, early media, DTMF over RFC 4733 and SIP INFO, hold/resume, ICE, two accounts with call swapping, a relay-only ICE call whose RTP flows through TURN over UDP, TCP and TLS, and two-process ICE calls relayed through TURN over UDP, TCP and TLS with an ICE restart in the middle |

Not verified by automation: the camera (`bskcapture`) needs a physical device, and CallKit/PushKit need a signed app with a VoIP push certificate. Both build in CI; see [Docs/Limitations.md](Docs/Limitations.md).

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
