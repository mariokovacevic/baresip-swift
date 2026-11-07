# Getting Started

Create an engine, register an account and place a call.

## Overview

One ``BaresipEngine`` serves the whole app; baresip itself is a process-wide singleton.
Every operation is `async` and returns once the engine thread has accepted it. Results that
arrive later, such as a successful registration or an answered call, come through
``BaresipEngine/events``.

### Add the package

Add `https://github.com/mariokovacevic/baresip-swift.git` as a package dependency and link the
`BaresipKit` product. Add `NSMicrophoneUsageDescription` to the app's Info.plist, and
`NSCameraUsageDescription` for video.

### Start the engine

```swift
import BaresipKit

var configuration = BaresipConfiguration()
configuration.userAgent = "ExampleApp/1.0"
let engine = try BaresipEngine(configuration: configuration)
engine.setLogHandler(BaresipOSLog.handler(subsystem: "com.example.app"))
try await engine.start()
```

### Listen for events

Start reading ``BaresipEngine/events`` before you register, so no event is missed.

```swift
Task {
    for await event in engine.events {
        switch event {
        case .registration(_, let state, _, let error):
            print("registration:", state, error.map { "\($0)" } ?? "")
        case .incomingCall(let info, _):
            try await engine.answer(callID: info.id)
        case .call(let call, let state, _):
            print(call, state)
        default:
            break
        }
    }
}
```

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
try await engine.hold(callID: call)
try await engine.resume(callID: call)
try await engine.hangup(callID: call)
```

A destination without a domain, such as `1002`, is completed with the account's domain.

### Stop the engine

```swift
await engine.stop()
```

Stopping unregisters every account, hangs up calls and joins the engine thread.
``BaresipEngine/start()`` starts it again with a fresh core.
