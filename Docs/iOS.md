# iOS and macOS setup

BaresipKit for iOS and macOS: a Swift package with one engine product and optional adapters for
the system frameworks, with the same features and type names as the [Android libraries](Android.md).
The C core is a binary target, `BaresipKitCore`, built into an XCFramework. This guide covers
installing the package, a quick start, the setup recipes, an app checklist and the sample app.
How the platforms share the core is in [Platforms.md](Platforms.md); the API reference and longer
articles are in the DocC catalog (Product > Build Documentation in Xcode), and the full
integration guide is [Integration.md](Integration.md).

> [!IMPORTANT]
> **Beta.** There is no release yet, and the API can still change. The Swift package runs in CI
> on the simulator and macOS, and CallKit, PushKit and the camera have been tested on an iPhone.
> Test it with your own devices and SIP server before relying on it.

## Modules

| Product | What it gives you | Import it when |
|---|---|---|
| `BaresipKit` | The engine: accounts, calls, media, messages, events, logging, TLS, NAT, life cycle helpers | Always |
| `BaresipKitAudio` | `BaresipAudioSessionController`: `AVAudioSession` setup, interruptions, output selection | You manage the audio session yourself (no CallKit, the simulator) |
| `BaresipKitVideo` | `BaresipVideoView` and `BaresipCallVideo` for remote video and the local camera | You show video |
| `BaresipKitCallKit` | `BaresipCallKitAdapter`: the system call screen, actions, audio session activation | You use CallKit (recommended on a device) |
| `BaresipKitLiveCommunication` | `BaresipLiveCommunicationAdapter`: the same with LiveCommunicationKit, CallKit's successor (iOS 17.4 or later) | You use LiveCommunicationKit instead of CallKit |
| `BaresipKitPushKit` | `BaresipPushKitAdapter`: VoIP pushes, push tokens as `Contact` parameters | You receive calls while the app is not running |
| `BaresipKitSwiftUI` | `BaresipPhone`, `BaresipPhoneCall`, `BaresipSelfView` | You build the UI in SwiftUI |

## Requirements

- iOS 16 or later, or macOS 13 or later on Apple silicon (partial, see [Features](../README.md#features))
- Xcode 16 or later, Swift 6
- To build the C core: macOS with Xcode, CMake and Python 3

## Installation

There is no release yet. Until the first one, build the C core yourself and add the checkout as
a local package:

```bash
git clone https://github.com/mariokovacevic/baresipkit.git
cd baresipkit
Build/build-xcframework.sh
```

Then add the folder in Xcode (File > Add Package Dependencies > Add Local), or in
`Package.swift`:

```swift
dependencies: [
    .package(path: "../baresipkit"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "BaresipKit", package: "baresipkit"),
        .product(name: "BaresipKitCallKit", package: "baresipkit"),
        .product(name: "BaresipKitPushKit", package: "baresipkit"),
        .product(name: "BaresipKitSwiftUI", package: "baresipkit"),
    ]),
]
```

Building the core takes a few minutes; module sets and options are in
[Docs/Building.md](Building.md). Once releases exist, each GitHub release carries the
prebuilt XCFramework and `Package.swift` points at it, so
`.package(url: "https://github.com/mariokovacevic/baresipkit.git", from: "x.y.z")` works
without building anything. See [Docs/Releasing.md](Releasing.md).

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

Server verification is always on and cannot be turned off. For a test server with a
self-signed certificate, put that certificate or its CA in `caCertificatesPEM`.

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
`pn-timeout`, the set that push-capable SIP servers use), and wakes the engine when a push
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
                uuid: nil,
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
*Push Contact Parameters*. To use LiveCommunicationKit instead of CallKit, see the DocC article
*LiveCommunicationKit*: the adapter is `BaresipLiveCommunicationAdapter`, and the push adapter
is created with `BaresipPushKitAdapter.reportingAsynchronously`, because LiveCommunicationKit
reports calls only asynchronously.

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
| Licenses | Ship the third-party notices, including OpenSSL's NOTICE (see [License](../README.md#license)) |
| Privacy | `BaresipKit` includes a privacy manifest; add your own app's entries |

## Sample app

[Examples/SampleApp](../Examples/SampleApp) is a SwiftUI app that uses every module: accounts with
TLS and certificates, calls with CallKit and PushKit, video with a self view, early media
preview, DTMF door codes, transfer, messages, contacts, ringtones, music on hold, recording, call
history and a shareable log, laid out as Zvono, a video intercom app with saved doors and an
Open button. Its Account screen exposes the NAT, SIP, codec and video settings, which makes it a handy test tool for a new SIP
server. A UI test registers and calls a test peer in CI.

```bash
cd Examples/SampleApp
xcodegen
open BaresipKitSample.xcodeproj
```

The screenshots in the [README](../README.md) come from the sample's screenshot test (CI's `sample-screenshots`
artifact, or `Tools/SampleScreenshots/run.sh` on a Mac);
`Tools/SampleScreenshots/readme_images.py` turns them into the small images in `Docs/Images`.
Zvono for Android is in [Android/zvono](../Android/zvono/README.md).

## Building from source and tests

[Building.md](Building.md) covers the XCFramework, the module sets and the host build;
[CONTRIBUTING.md](../CONTRIBUTING.md) has the commands for the C tests, the Swift tests on a
simulator and the integration tests against Asterisk and coturn. What needs a physical iPhone
is listed in [DeviceTesting.md](DeviceTesting.md).

## Releasing

[Releasing.md](Releasing.md) describes how a release is cut and versioned, and the XCFramework
checksum the package pins.

## Documentation

| Where | What |
|---|---|
| DocC (Product > Build Documentation in Xcode) | The API reference and the Getting Started, Audio Session, Video, CallKit, PushKit, SwiftUI, Network Changes and Push Contact Parameters articles |
| [Integration.md](Integration.md) | The full integration guide |
| [Platforms.md](Platforms.md) | How the platforms share the core, and parity with Android type by type and test by test |
| [Architecture.md](Architecture.md) | The layers, from the C core to the adapters |
| [C-ABI.md](C-ABI.md) | The C ABI the Swift layer binds |
| [Troubleshooting.md](Troubleshooting.md) | Reading the log and the usual registration, media, ICE, push and background failures |
| [Interop.md](Interop.md), [Limitations.md](Limitations.md) | Servers and devices BaresipKit has been tried with, and the known limits |
