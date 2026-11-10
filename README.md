# BaresipKit

**SIP voice and video calls for iOS, in Swift.**

![Status: beta](https://img.shields.io/badge/status-beta-orange)
![Platforms: iOS 16+ | macOS 13+](https://img.shields.io/badge/platforms-iOS%2016%2B%20%7C%20macOS%2013%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138)
![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-green)

BaresipKit wraps the [baresip](https://github.com/baresip/baresip) user agent and the
[libre](https://github.com/baresip/re) SIP stack behind a small, versioned C ABI and an
`async`/`await` Swift API. Optional modules connect it to the audio session, video views,
SwiftUI, CallKit and PushKit, so an app can go from "register an account" to "answer a pushed
video call on the lock screen" with a few dozen lines of code. The C core ships as a binary
XCFramework inside a Swift package.

> [!IMPORTANT]
> **Beta.** BaresipKit is in active development and has no release yet. The API can still
> change, and it is tested on a limited set of devices and SIP servers. Test it with your own
> setup before relying on it.

## Contents

- [Highlights](#highlights)
- [Modules](#modules)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Setup recipes](#setup-recipes)
  - [Engine, account and TLS](#engine-account-and-tls)
  - [Logging](#logging)
  - [SwiftUI](#swiftui)
  - [CallKit](#callkit)
  - [PushKit with CallKit](#pushkit-with-callkit)
  - [Audio without CallKit](#audio-without-callkit)
  - [Video calls](#video-calls)
  - [Early media preview and door stations](#early-media-preview-and-door-stations)
  - [NAT traversal: STUN, ICE and TURN](#nat-traversal-stun-ice-and-turn)
  - [Background and network changes](#background-and-network-changes)
  - [Hold, transfer and several calls](#hold-transfer-and-several-calls)
  - [Messages, recording and statistics](#messages-recording-and-statistics)
- [App checklist](#app-checklist)
- [Features](#features)
- [Documentation](#documentation)
- [Sample app](#sample-app)
- [Repository layout](#repository-layout)
- [Contributing and security](#contributing-and-security)
- [License](#license)

## Highlights

- **Registration** over UDP, TCP and TLS, with private CAs, mutual TLS and SPKI pinning.
- **Audio** with Opus, G.722 and G.711; **video** with H.264 through VideoToolbox and
  zero-copy decoded frames.
- **CallKit and PushKit** adapters that handle the hard parts: reporting a pushed call before
  the delegate returns, matching it to the INVITE that follows, and waiting for the engine's
  result before completing a CallKit action.
- **SwiftUI state**: `BaresipPhone` and `BaresipPhoneCall` publish registrations, calls, mute,
  hold, video and DTMF, with ready-made video and self-view components.
- **Door stations and intercoms**: early media preview before answering, video in audio calls,
  picture updates over SIP INFO, DTMF door codes with a confirmation reply.
- **NAT traversal**: STUN, ICE with TURN over UDP, TCP and TLS, ICE restart, RTCP
  multiplexing and a NAT pinhole for media relays.
- **App life cycle**: going offline in the background and back online when the app becomes
  active, and re-registering after network changes.

## Modules

| Product | What it gives you | Import it when |
|---|---|---|
| `BaresipKit` | The engine: accounts, calls, media, messages, events, logging, TLS, NAT, life cycle helpers | Always |
| `BaresipKitAudio` | `BaresipAudioSessionController`: `AVAudioSession` setup, interruptions, output selection | You manage the audio session yourself (no CallKit, the simulator) |
| `BaresipKitVideo` | `BaresipVideoView` and `BaresipCallVideo` for remote video and the local camera | You show video |
| `BaresipKitCallKit` | `BaresipCallKitAdapter`: the system call screen, actions, audio session activation | You use CallKit (recommended on a device) |
| `BaresipKitPushKit` | `BaresipPushKitAdapter`: VoIP pushes, push tokens as `Contact` parameters | You receive calls while the app is not running |
| `BaresipKitSwiftUI` | `BaresipPhone`, `BaresipPhoneCall`, `BaresipSelfView` | You build the UI in SwiftUI |

## Requirements

- iOS 16 or later, or macOS 13 or later on Apple silicon (partial, see [Features](#features))
- Xcode 16 or later, Swift 6
- To build the C core: macOS with Xcode, CMake and Python 3

## Installation

There is no release yet. Until the first one, build the C core yourself and add the checkout as
a local package:

```bash
git clone https://github.com/mariokovacevic/baresip-swift.git
cd baresip-swift
Build/build-xcframework.sh
```

Then add the folder in Xcode (File > Add Package Dependencies > Add Local), or in
`Package.swift`:

```swift
dependencies: [
    .package(path: "../baresip-swift"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "BaresipKit", package: "baresip-swift"),
        .product(name: "BaresipKitCallKit", package: "baresip-swift"),
        .product(name: "BaresipKitPushKit", package: "baresip-swift"),
        .product(name: "BaresipKitSwiftUI", package: "baresip-swift"),
    ]),
]
```

Building the core takes a few minutes; module sets and options are in
[Docs/Building.md](Docs/Building.md). Once releases exist, each GitHub release carries the
prebuilt XCFramework and `Package.swift` points at it, so
`.package(url: "https://github.com/mariokovacevic/baresip-swift.git", from: "x.y.z")` works
without building anything. See [Docs/Releasing.md](Docs/Releasing.md).

## Quick start

Register an account and place a call:

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
    switch event {
    case .registration(_, .registered, _, _):
        let call = try await engine.makeCall(destination: "sip:bob@example.com")
        print("calling", call)
    case .registration(_, .failed, _, let error):
        print("registration failed:", error as Any)
    case .call(let call, let state, _):
        print(call, state)
    default:
        break
    }
}
```

Every subscriber to `engine.events` receives every event, so a view model, the CallKit adapter
and your own logging can all listen at once.

## Setup recipes

Each recipe is a complete piece you can copy; together they make a production VoIP app. The
[sample app](#sample-app) wires all of them up.

### Engine, account and TLS

The engine configuration holds what is shared by all accounts: TLS trust, codecs, video size,
the number of calls and logging. The account configuration holds the server, credentials, media
encryption, NAT traversal and DTMF method.

```swift
import BaresipKit

var configuration = BaresipConfiguration()
configuration.userAgent = "MyApp/1.0"
configuration.maxCalls = 2
configuration.video = BaresipVideoConfiguration(width: 640, height: 480,
                                                framesPerSecond: 15, bitrate: 600_000)

// A private CA, a client certificate for mutual TLS, and an optional SPKI pin.
configuration.tls = BaresipTLSConfiguration(
    caCertificatesPEM: try BaresipCertificates.caBundle(from: caFileData),        // PEM or DER
    clientCertificatePEM: try BaresipCertificates.clientIdentity(from: clientPEM), // cert + key
    pinnedSPKISHA256: ["base64-encoded-sha256-of-the-server-public-key="]
)

let engine = try BaresipEngine(configuration: configuration)
try await engine.start()

let account = try await engine.addAccount(BaresipAccountConfiguration(
    aor: "sip:alice@example.com",
    displayName: "Alice",
    registrar: "sip:pbx.example.com:5061;transport=tls",
    transport: .tls,
    authUser: "alice",
    authPassword: password,                 // passed to the core, never logged
    registerExpires: .seconds(600),
    mediaEncryption: .srtpMandatory,
    dtmfMode: .auto,                        // RFC 4733 when supported, SIP INFO otherwise
    audioCodecs: ["opus", "G722", "PCMA"]   // empty uses the engine's list
))
try await engine.register(accountID: account)
```

Server verification is always on in release builds. `BaresipTLSConfiguration.insecureSkippingServerVerification()`
exists only in debug builds, for test servers.

### Logging

Send the engine's log to the unified log, to a rotating file the user can share, or both.
Passwords, digest responses, push tokens and DTMF digits are redacted before any handler sees
them.

```swift
let fileLog = BaresipFileLog()  // Library/Logs, 50 MB per file, 7 days
engine.setLogHandler(fileLog.handler(forwardingTo: BaresipOSLog.handler(subsystem: "com.example.app")))

fileLog.write("user tapped Call", tag: "ui")
let filesToShare = fileLog.files()
```

Set `configuration.logSIPTrace = true` to log full SIP messages while debugging.

### SwiftUI

`BaresipPhone` turns the engine's events into published state. Create it once per engine and
keep it.

```swift
import BaresipKit
import BaresipKitSwiftUI

struct PhoneView: View {
    @StateObject private var phone: BaresipPhone

    init(engine: BaresipEngine, callKit: BaresipCallController?) {
        _phone = StateObject(wrappedValue: BaresipPhone(engine: engine, callController: callKit))
    }

    var body: some View {
        Group {
            if let call = phone.incomingCall {
                IncomingCallView(call: call)
            } else if let call = phone.activeCall {
                InCallView(call: call)
            } else {
                Button("Call Bob") {
                    Task { _ = try? await phone.makeCall(to: "sip:bob@example.com", video: true) }
                }
            }
        }
        .task { await phone.run() }
    }
}

struct IncomingCallView: View {
    @ObservedObject var call: BaresipPhoneCall

    var body: some View {
        VStack {
            Text(call.displayName)
            HStack {
                Button("Decline") { Task { try? await call.reject() } }
                Button("Answer") { Task { try? await call.answer(video: call.hasVideo) } }
            }
        }
    }
}
```

`activeCall` follows answering, switching and ending calls; when it ends, a held call takes its
place and is resumed. Pass the CallKit adapter as `callController` (next recipe) and every
action goes through CallKit, so the system call screen and your UI stay in step.

### CallKit

On a device, let CallKit own the call screen and the audio session.

```swift
import BaresipKitCallKit

var callKitConfiguration = BaresipCallKitConfiguration(supportsVideo: true,
                                                       maximumCallsPerCallGroup: 1,
                                                       iconTemplateImageData: iconPNG,
                                                       ringtoneSound: "ring.caf")
callKitConfiguration.sendsCameraOnAnswer = false   // answer video calls with the camera off
callKitConfiguration.pushInviteTimeout = .seconds(30)

let callKit = BaresipCallKitAdapter(engine: engine, configuration: callKitConfiguration)
let phone = BaresipPhone(engine: engine, callController: callKit)
```

Incoming INVITEs are reported to CallKit as soon as they arrive. With the adapter as the
phone's call controller, `phone.makeCall`, `call.answer`, `call.hangUp`, `call.setOnHold` and
`call.setMuted` go through `CXCallController` and return once the engine carried the action
out, throwing the engine's error when it failed. Without SwiftUI, use the adapter directly:

```swift
let uuid = try await callKit.startOutgoingCall(to: "sip:bob@example.com", video: false)
try await callKit.setMuted(true, uuid: uuid)
try await callKit.setHeld(true, uuid: uuid)
try await callKit.endCall(uuid: uuid)

callKit.setMuteHandler { call, muted in
    print(call, "muted on the system screen:", muted)
}
```

In the simulator CallKit never activates the audio session; there, pass `nil` as the call
controller and use [Audio without CallKit](#audio-without-callkit).

### PushKit with CallKit

To ring while the app is not running, the SIP server (or a push proxy) sends a VoIP push when a
call arrives for a registered device. The adapter registers for VoIP pushes, sends the token to
the registrar as `Contact` parameters (`app-id`, `pn-type`, `pn-tok`, `pn-silent`,
`pn-timeout`, the set used by servers such as Flexisip), and wakes the engine when a push
arrives. For RFC 8599 parameters (`pn-provider`, `pn-prid`, `pn-param`), set them yourself with
`engine.updateContactParameters(accountID:parameters:reregisterNow:)`.

iOS terminates an app that returns from a VoIP push without reporting a call to CallKit, and a
push can launch the app, so create everything in
`application(_:didFinishLaunchingWithOptions:)`:

```swift
import UIKit
import BaresipKit
import BaresipKitCallKit
import BaresipKitPushKit

@MainActor
final class VoIPService {
    let engine: BaresipEngine
    let callKit: BaresipCallKitAdapter
    private(set) var push: BaresipPushKitAdapter?

    init() throws {
        engine = try BaresipEngine(configuration: BaresipConfiguration())
        callKit = BaresipCallKitAdapter(engine: engine,
                                        configuration: BaresipCallKitConfiguration(supportsVideo: true))

        let callKit = callKit
        push = BaresipPushKitAdapter(engine: engine, appID: "com.example.app") { payload in
            // Runs inside the PushKit delegate method. Report the call before returning:
            // no `await`, no `Task`. The payload keys are whatever your push sender uses.
            callKit.reportIncomingCallFromPush(
                uuid: UUID(),
                remoteURI: payload["from"] as? String,      // "sip:bob@example.com" or "bob"
                displayName: payload["name"] as? String,
                hasVideo: payload["video"] as? Bool ?? false
            ) { error in
                if let error { print("CallKit refused the call:", error) }
            }
        }
        push?.setErrorHandler { step, error in
            print("push adapter:", step, error)
        }
    }

    func start(account configuration: BaresipAccountConfiguration) async throws {
        try await engine.start()
        let account = try await engine.addAccount(configuration)
        push?.bind(accountID: account)    // the token goes into this account's Contact
        try await engine.register(accountID: account)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    @MainActor var voip: VoIPService?

    @MainActor
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        voip = try? VoIPService()
        application.registerForRemoteNotifications()   // optional: a regular APNs token as well
        Task {
            do {
                try await voip?.start(account: loadAccountConfiguration())   // your own settings
            } catch {
                print("SIP start failed:", error)
            }
        }
        return true
    }

    @MainActor
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        voip?.push?.updateRemoteToken(token)   // sent next to the VoIP token in pn-tok
    }
}
```

The INVITE that follows is bound to the pushed call by the caller's user and host, so the
system screen shows one call. If the user already tapped Answer, the call is answered as soon
as it arrives; if no INVITE comes within `pushInviteTimeout`, the call ends. Use
`push?.updateAppID(_:)` to switch between the sandbox and production push environments.

For the server side and the exact parameters, see the DocC articles *PushKit*, *CallKit* and
*Push Contact Parameters*.

### Audio without CallKit

In the simulator, in UI tests, or in an app that does not use CallKit, the
`BaresipKitAudio` controller configures and activates the session and forwards interruptions
and route changes to the engine:

```swift
import BaresipKitAudio

let audio = BaresipAudioSessionController(engine: engine) { route in
    print("audio route:", route)
}
try audio.configureForVoIP(allowBluetooth: true, defaultToSpeaker: false)
try await audio.activate()
try audio.setSpeakerEnabled(true)
```

The controller also lists the available outputs (earpiece, loudspeaker, headphones,
Bluetooth, car audio) and routes call audio to the one the user picks. See the DocC article
*Audio Session*.

### Video calls

Place or answer with `video: true` to send the camera. Show the other side with
`BaresipCallVideo` and your own camera with `BaresipSelfView`, which appears only while the
camera is sent, mirrors the front camera and switches cameras when tapped:

```swift
import BaresipKitSwiftUI
import BaresipKitVideo

struct InCallView: View {
    @ObservedObject var call: BaresipPhoneCall

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if call.isReceivingVideo {
                BaresipCallVideo(call: call)                       // remote video
                    .ignoresSafeArea()
            }
            VStack {
                Spacer()
                HStack {
                    Button(call.isSendingVideo ? "Camera off" : "Camera on") {
                        Task { try? await call.setVideoEnabled(!call.isSendingVideo) }
                    }
                    Button("Flip") { Task { try? await call.switchCamera() } }
                    Button(call.isMuted ? "Unmute" : "Mute") {
                        Task { try? await call.setMuted(!call.isMuted) }
                    }
                    Button("End") { Task { try? await call.hangUp() } }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            BaresipSelfView(call: call, size: CGSize(width: 100, height: 140))
                .padding()
        }
    }
}
```

`BaresipCallVideo(call: call, source: .local)` shows your camera full size. In UIKit, use
`BaresipVideoView` and give its `renderer` to `engine.setVideoRenderer(_:callID:)`. To change
the camera without the call object, use `engine.setCamera(.back, callID:)`.

### Early media preview and door stations

Show and hear a caller before answering, without sending your microphone or camera, by
replying with a receive-only 183 Session Progress:

```swift
if let call = phone.incomingCall {
    try await call.startPreview(video: true, audio: true)
}
```

To preview every incoming call automatically, set `answerEarlyMedia: true` on the account.
On a phone with CallKit, iOS plays the preview audio only after the call is answered; the
picture shows while it rings.

Door stations often need a few more settings, all on the account:

```swift
var account = BaresipAccountConfiguration(aor: aor, authPassword: password)
account.answerEarlyMedia = true             // show the door camera while it rings
account.pictureUpdateOverSIPInfo = true     // stations that ignore RTCP PLI/FIR
account.dtmfMode = .sipInfo                 // door codes as SIP INFO
account.incomingHeaders = ["X-Device-ID"]   // keep a header of incoming INVITEs
```

Open the door and wait for the station to confirm with a DTMF digit:

```swift
switch try await call.sendDTMF("1234#", expectingReply: "1", timeout: .seconds(5)) {
case .confirmed: print("door opened")
case .other(let digit): print("station replied", digit)
case .noReply: print("no confirmation")
}
```

Read a kept header with `engine.incomingHeader("X-Device-ID", callID:)`.

### NAT traversal: STUN, ICE and TURN

```swift
var account = BaresipAccountConfiguration(aor: aor, authPassword: password)
account.nat = BaresipNATConfiguration(
    mode: .ice,                                   // .none, .stun or .ice
    stunURI: "stun:stun.example.com:3478",
    turnServers: [BaresipTURNServer(uri: "turns:turn.example.com:5349",
                                    username: "user", password: turnPassword)],
    rtpTimeout: .seconds(30),                     // end a call without RTP; .zero turns it off
    rtcpMultiplexing: true,                       // RTCP on the RTP port (RFC 5761)
    pinhole: true                                 // receive-only streams open the NAT for relays
)
```

`configuration.iceRelayOnly = true` forces media through TURN, which helps when testing a
relay. Without ICE, turn on `pinhole` when a media relay such as rtpengine forwards the
caller's media only after it has seen a packet from you.

### Background and network changes

`BaresipAppLifecycle` takes the account offline when the app goes to the background without a
call, brings it back online when the app becomes active, and disconnects cleanly when the app
is terminated. `BaresipNetworkMonitor` re-registers and moves running calls when the network
changes.

```swift
let lifecycle = BaresipAppLifecycle(engine: engine)
lifecycle.backgroundBehavior = .goOffline       // .stayOnline, .suspend (default) or .goOffline
lifecycle.setChangeHandler { change in
    print("lifecycle:", change)                 // .suspended, .wentOffline, .backOnline, .disconnected
}
lifecycle.start()

let network = BaresipNetworkMonitor(engine: engine)
network.setChangeHandler { path in print("network:", path) }
network.start()
```

With PushKit, `.goOffline` is the usual choice: the server reaches the app through a push, so
nothing needs to stay registered in the background. Calls in progress are never interrupted;
the account goes offline after the last call ends.

### Hold, transfer and several calls

```swift
try await engine.hold(callID: first)
let second = try await engine.makeCall(destination: "sip:carol@example.com")

try await engine.blindTransfer(callID: first, to: "sip:dave@example.com")
try await engine.attendedTransfer(callID: first, replacing: second)   // connect first and second

try await phone.makeActive(otherCall)            // SwiftUI: the engine holds the others
```

Incoming REFERs are followed unless the account sets `acceptTransfers = false`. The engine
allows `configuration.maxCalls` calls at once.

### Messages, recording and statistics

```swift
let message = try await engine.sendMessage(to: "sip:bob@example.com", text: "Hello")

try await engine.startRecording(callID: call, to: recordingURL)   // stereo WAV

let stats = try await engine.callStatistics(callID: call)        // loss, jitter, RTT, MOS
print(stats)
```

## App checklist

Before shipping a VoIP app built on BaresipKit:

| Where | What |
|---|---|
| Info.plist | `NSMicrophoneUsageDescription`; `NSCameraUsageDescription` for video |
| Info.plist | `UIBackgroundModes`: `audio` and `voip` |
| Signing & Capabilities | Push Notifications (for PushKit), Background Modes |
| Push sender | A VoIP push certificate or token-based APNs key; the topic is `<bundle id>.voip` |
| SIP server | Reads the push parameters from the `Contact` and sends a VoIP push for a call to a registered device |
| CallKit | An icon template (`iconTemplateImageData`) and, optionally, a ringtone in the bundle |
| Licenses | Ship the third-party notices, including OpenSSL's NOTICE (see [License](#license)) |
| Privacy | `BaresipKit` includes a privacy manifest; add your own app's entries |

## Features

| Feature | Status | Notes |
|---|---|---|
| Registration over UDP, TCP and TLS | Supported | Tested against Asterisk and a TLS test registrar in CI |
| TLS with a private CA, mutual TLS and SPKI pinning | Supported | |
| Audio calls: Opus, G.722, G.711 | Supported | |
| Video calls: H.264 through VideoToolbox | Supported | Zero-copy decoded frames; VP8 in the `full` module set |
| Hold, resume, mute, DTMF (RFC 4733 and SIP INFO) | Supported | DTMF with a confirmation reply for door stations |
| Several calls at once, switching the active call | Supported | `maxCalls` in the configuration |
| Blind and attended transfer (REFER, Replaces) | Supported | |
| SIP MESSAGE (RFC 3428) | Supported | |
| Early media preview of incoming calls | Supported | Receive-only 183 Session Progress, also video only |
| Door stations: video in audio calls, calls without audio, headers of incoming INVITEs | Supported | `video` only decides whether your camera is sent |
| Picture update requests over SIP INFO (RFC 5168) | Supported | For devices that ignore RTCP PLI/FIR |
| Self view, camera switching | Supported | `BaresipSelfView`, `BaresipCameraPosition` |
| Video snapshots | Supported | `BaresipVideoView.snapshot()` |
| Choosing the audio output | Supported | Earpiece, loudspeaker, headphones, Bluetooth, car audio |
| SRTP (SDES) and DTLS-SRTP | Supported | |
| ICE with STUN and TURN over UDP, TCP and TLS, ICE restart | Supported | |
| RTCP multiplexing (RFC 5761) and a NAT pinhole for receive-only streams | Supported | For media relays such as rtpengine |
| Adaptive video bitrate from RTCP loss | Supported | |
| Going offline in the background, network change handling | Supported | `BaresipAppLifecycle`, `BaresipNetworkMonitor` |
| Call recording to stereo WAV | Supported | |
| Statistics: loss, jitter, RTT, MOS estimate | Supported | |
| File log with rotation | Supported | `BaresipFileLog`, secrets redacted |
| macOS (Apple silicon) | Partial | `BaresipKit`, `BaresipKitVideo` frames and `BaresipKitSwiftUI`; built and unit-tested in CI, not tested in real calls; no echo cancellation; the audio session, CallKit and PushKit adapters and `BaresipVideoView` are iOS only |
| Camera capture (`bskcapture`) | Supported | Tested on a device; CI only builds it |
| SwiftUI state (`BaresipPhone`, `BaresipPhoneCall`) | Supported | iOS 16 and later |
| CallKit adapter | Supported | Tested on a device; build and unit tests in CI |
| PushKit adapter | Supported | Tested on a device with VoIP pushes; build and unit tests in CI |
| SIP over secure WebSocket | Partial | Transport available in the API, not covered by tests |
| ZRTP, conferencing, presence, H.265 | Not supported | |

What CI covers and what it does not is listed in [Docs/Limitations.md](Docs/Limitations.md).

## Documentation

| Where | What |
|---|---|
| DocC (Product > Build Documentation in Xcode) | API reference and the Getting Started, Audio Session, Video, CallKit, PushKit, SwiftUI, Network Changes and Push Contact Parameters articles |
| [Docs/Integration.md](Docs/Integration.md) | The full integration guide |
| [Docs/Troubleshooting.md](Docs/Troubleshooting.md) | Common failures and how to read the log for each |
| [Docs/Architecture.md](Docs/Architecture.md) | Layers, threading and ownership |
| [Docs/Building.md](Docs/Building.md) | Building the XCFramework and module sets |
| [Docs/C-ABI.md](Docs/C-ABI.md) | Conventions of the C ABI in `baresip_kit.h` |
| [Docs/CompatibilityMatrix.md](Docs/CompatibilityMatrix.md) | Each requirement and how baresip covers it |
| [Docs/Limitations.md](Docs/Limitations.md) | Known limits and what is not tested |
| [Docs/DeviceTesting.md](Docs/DeviceTesting.md) | The manual test on a physical iPhone |
| [Docs/Releasing.md](Docs/Releasing.md) | How a release is cut and versioned |

## Sample app

[Examples/SampleApp](Examples/SampleApp) is a SwiftUI app that uses every module: accounts with
TLS and certificates, calls with CallKit and PushKit, video with a self view, early media
preview, DTMF door codes, transfer, messages, recording, call history and a shareable log. Its
Account screen exposes the NAT, SIP, codec and video settings, which makes it a handy test tool
for a new SIP server. A UI test registers and calls a test peer in CI.

```bash
cd Examples/SampleApp
xcodegen
open BaresipKitSample.xcodeproj
```

## Repository layout

```
Package.swift   Swift package; the C core is the BaresipKitCore binary target
Core/           the C facade (include/baresip_kit.h, src/), built into the XCFramework
Sources/        BaresipKitBridge (C helpers), BaresipKit (Swift API) and the adapters
Tests/          BaresipKitTests (XCTest), Core (C tests), Fuzz, Integration (Asterisk and coturn)
Examples/       the sample app (XcodeGen project)
Build/          pinned versions, module sets and the XCFramework build script
Patches/        small patches applied to the pinned baresip and libre sources
Scripts/        lint.sh and format.sh
Docs/           guides, the C ABI reference and research notes
Tools/          the Contact parameter proof and test registrars
```

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) for building, testing and the commit convention, and
[SECURITY.md](SECURITY.md) for reporting vulnerabilities privately. This project follows the
[Contributor Covenant](CODE_OF_CONDUCT.md).

## License

BaresipKit is available under the BSD 3-Clause license; see [LICENSE](LICENSE). libre,
baresip, Opus and libvpx are BSD-3-Clause too. OpenSSL, built into the XCFramework for TLS,
DTLS-SRTP and crypto, is Apache License 2.0, which requires its NOTICE text to ship with the
app; the release workflow bundles it, and every other license text, into
`BaresipKitCore-licenses.zip`, and the texts are also in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). H.264 is patent-encumbered; using
VideoToolbox's codec is covered by Apple's platform license, but read the note in
[DEPENDENCIES.md](DEPENDENCIES.md) before shipping. The full dependency inventory, with
versions and roles, is in DEPENDENCIES.md.
