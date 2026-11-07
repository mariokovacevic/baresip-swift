# BaresipKit

BaresipKit is an open-source Swift SDK for SIP voice and video calls on iOS. It wraps the [baresip](https://github.com/baresip/baresip) user agent and the [libre](https://github.com/baresip/re) stack behind a small, versioned C ABI and an `async`/`await` Swift API, with optional adapters for the audio session, video views, CallKit and PushKit. The C core ships as a binary XCFramework inside a Swift package. License: BSD-3-Clause, the same as baresip.

## Features

| Feature | Status | Notes |
|---|---|---|
| Registration over UDP, TCP and TLS | Supported | Tested against Asterisk and a TLS test registrar in CI |
| TLS with a private CA, mutual TLS and SPKI pinning | Supported | |
| Audio calls: Opus, G.711 | Supported | |
| Video calls: H.264 through VideoToolbox | Supported | Zero-copy decoded frames; VP8 in the `full` module set |
| Hold, resume, mute, DTMF (RFC 4733 and SIP INFO) | Supported | |
| Several calls at once, switching the active call | Supported | `maxCalls` in the configuration |
| Blind and attended transfer (REFER, Replaces) | Supported | |
| SIP MESSAGE (RFC 3428) | Supported | |
| Early media preview of incoming calls | Supported | Receive-only 183 Session Progress |
| SRTP (SDES) and DTLS-SRTP | Supported | |
| ICE with STUN and TURN over UDP, TCP and TLS, ICE restart | Supported | |
| Adaptive video bitrate from RTCP loss | Supported | |
| Call recording to stereo WAV | Supported | |
| Statistics: loss, jitter, RTT, MOS estimate | Supported | |
| Camera capture (`bskcapture`) | Partial | Builds in CI; needs a physical device to test |
| CallKit and PushKit adapters | Partial | Build and unit tests in CI; need a signed app and a VoIP push certificate to test end to end |
| SIP over secure WebSocket | Partial | Transport available in the API, not covered by tests |
| ZRTP, conferencing, presence, G.722, H.265 | Not supported | |

What CI covers and what it does not is listed in [Docs/Limitations.md](Docs/Limitations.md).

## Requirements

- iOS 17 or later
- Xcode 16 or later (Swift 6)
- To build the C core: macOS with Xcode, CMake and Python 3

## Installation

Add the package in Xcode (File > Add Package Dependencies) or in `Package.swift`:

```swift
.package(url: "https://github.com/mariokovacevic/baresip-swift.git", from: "1.0.0")
```

Then add the products you need: `BaresipKit`, and optionally `BaresipKitAudio`, `BaresipKitVideo`, `BaresipKitCallKit` and `BaresipKitPushKit`.

Until the first tagged release publishes the XCFramework, build it locally once with `Build/build-xcframework.sh`; `Package.swift` picks up `Build/out/BaresipKitCore.xcframework` automatically. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Example: register and call

```swift
import BaresipKit

let engine = try BaresipEngine(configuration: BaresipConfiguration())
try await engine.start()

let account = try await engine.addAccount(BaresipAccountConfiguration(
    aor: "sip:alice@example.com",
    authPassword: "example-password"
))
try await engine.register(accountID: account)

for await event in engine.events {
    if case .registration(_, .registered, _, _) = event {
        let call = try await engine.makeCall(destination: "sip:bob@example.com")
        print("calling", call)
        break
    }
}
```

The app needs the `NSMicrophoneUsageDescription` key, and `NSCameraUsageDescription` for video. A VoIP app also needs the `audio` and `voip` background modes.

## Documentation

- The DocC documentation of the package: Getting Started, Audio Session, Video, CallKit, PushKit and Push Contact Parameters. Build it with Product > Build Documentation in Xcode.
- [Docs/Integration.md](Docs/Integration.md): the full integration guide.
- [Docs/Architecture.md](Docs/Architecture.md): the layers and threading model.
- [Docs/Building.md](Docs/Building.md): building the XCFramework and module sets.
- [Docs/Limitations.md](Docs/Limitations.md): known limits and what is not tested.
- [Examples/SampleApp](Examples/SampleApp): a SwiftUI app with accounts, calls, video, transfer, messages and recording.

## Repository layout

```
Package.swift   Swift package; the C core is the BaresipKitCore binary target
Core/           the C facade (include/baresip_kit.h, src/), built into the XCFramework
Sources/        BaresipKitBridge (C helpers), BaresipKit (Swift API) and the adapters
Tests/          BaresipKitTests (XCTest), Core (C tests), Fuzz, Integration (Asterisk and coturn)
Examples/       the sample app (xcodegen project)
Build/          pinned versions, module sets and the XCFramework build script
Patches/        small patches applied to the pinned baresip and libre sources
Scripts/        lint.sh and format.sh
Docs/           guides and the C ABI reference
Tools/          the Contact parameter proof and test registrars
```

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) for building, testing and the commit convention, and [SECURITY.md](SECURITY.md) for reporting vulnerabilities privately. This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).

## License

BaresipKit is available under the BSD 3-Clause license; see [LICENSE](LICENSE). Third-party components and their licenses are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [DEPENDENCIES.md](DEPENDENCIES.md). H.264 is patent-encumbered; read the note in DEPENDENCIES.md before shipping.
