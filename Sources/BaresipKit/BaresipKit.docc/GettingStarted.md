# Getting Started

Create an engine, register an account and place a call.

## Overview

One ``BaresipEngine`` serves the whole app; baresip itself is a process-wide singleton.
Every operation is `async` and returns once the engine thread has accepted it. Results that
arrive later, such as a successful registration or an answered call, come through
``BaresipEngine/events``.

### Add the package

There is no release yet. Clone `https://github.com/mariokovacevic/baresip-swift.git`, build the C
core with `Build/build-xcframework.sh`, add the checkout as a local package and link the
`BaresipKit` product. Add `NSMicrophoneUsageDescription` to the app's Info.plist, and
`NSCameraUsageDescription` for video. The package includes a privacy manifest for the SDK; the
app declares its own data use and API use in its own manifest.

### Create the engine

```swift
import BaresipKit

var configuration = BaresipConfiguration()
configuration.userAgent = "ExampleApp/1.0"
let engine = try BaresipEngine(configuration: configuration)
engine.setLogHandler(BaresipOSLog.handler(subsystem: "com.example.app"))
```

### Listen for events

``BaresipEngine/events`` returns a new stream each time it is read, and a stream receives the
events from that moment on. Take the stream right after creating the engine, before `start()`,
and iterate it in a task. A stream created inside the task would miss whatever happens before
the task first runs.

```swift
let events = engine.events
let listener = Task { [weak engine] in
    for await event in events {
        switch event {
        case .registration(_, let state, _, let error):
            print("registration:", state, error.map { "\($0)" } ?? "")
        case .incomingCall(let info, _):
            try? await engine?.answer(callID: info.id)
        case .call(let call, let state, _):
            print(call, state)
        default:
            break
        }
    }
}
```

The task holds the engine weakly, so listening does not keep the engine alive: the stream ends
when the engine is deallocated, and the task ends with it. Cancel `listener` to stop earlier.

### Start the engine

```swift
try await engine.start()
```

Only one engine may run per process. ``BaresipEngine/stop(timeout:)`` ends the calls and
removes the accounts; add them again after the next start.

### Register an account

```swift
let account = try await engine.addAccount(BaresipAccountConfiguration(
    aor: "sip:alice@example.com",
    authPassword: "example-password"
))
try await engine.register(accountID: account)
```

TLS is the default transport. The server certificate is verified against the system trust
store; for a private CA set ``BaresipTLSConfiguration/caCertificatesPEM`` in the engine
configuration.

### Place and end a call

```swift
let call = try await engine.makeCall(destination: "sip:bob@example.com")
try await engine.hangup(callID: call)
```

A destination without a domain, such as `1002`, is completed with the account's domain.

### Door stations and intercoms

Every call negotiates video, so the other side's picture, such as a door station's camera, is
shown in audio calls too; `video` only decides whether your camera is sent. A call can also
leave the audio inactive, to watch the camera or send a door-opening DTMF code without opening
the microphone:

```swift
let watch = try await engine.makeCall(destination: "sip:door@example.com", audio: false)
try await engine.answer(callID: incoming.id, video: false, audio: true)
```

See ``BaresipEngine/makeCall(accountID:destination:video:audio:)`` and
``BaresipEngine/answer(callID:video:audio:)``. Headers that a station adds to its INVITE are kept
when the account names them in ``BaresipAccountConfiguration/incomingHeaders``:

```swift
var account = BaresipAccountConfiguration(aor: "sip:alice@example.com")
account.incomingHeaders = ["X-Device-ID"]
let device = try await engine.incomingHeader("X-Device-ID", callID: incoming.id)
```

Stations that ignore RTCP picture requests get them as SIP INFO with
``BaresipAccountConfiguration/pictureUpdateOverSIPInfo``. ``BaresipCallInfo/isMicrophoneMuted``
reports the real mute state for a mute button.

### Stop the engine

```swift
await engine.stop()
```

Stopping unregisters every account, hangs up calls and joins the engine thread.
``BaresipEngine/start()`` starts it again with a fresh core.
