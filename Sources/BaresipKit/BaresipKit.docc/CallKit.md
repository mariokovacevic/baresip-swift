# CallKit

Show calls on the system call screen.

## Overview

`BaresipCallKitAdapter` from the `BaresipKitCallKit` module reports incoming calls to CallKit,
starts outgoing calls through `CXCallController`, and carries out the user's actions on the
engine: answer, end, hold, mute and DTMF. It also forwards the audio session activation.

```swift
import BaresipKitCallKit

let callKit = BaresipCallKitAdapter(
    engine: engine,
    configuration: BaresipCallKitConfiguration(supportsVideo: true)
)
let uuid = try await callKit.startOutgoingCall(to: "sip:bob@example.com", video: false)
```

An INVITE is reported to CallKit as soon as it arrives. To show the caller's video or audio
before answering, see the early media section in <doc:AudioSession>.

### Calls announced by a push

After a VoIP push, report the call before the INVITE arrives:

```swift
try await callKit.reportIncomingCallFromPush(
    uuid: UUID(),
    remoteURI: "sip:bob@example.com",
    displayName: "Bob",
    hasVideo: false
)
```

The INVITE that follows is matched to that call by the caller's user and host. If the user has
already answered, the call is answered as soon as it arrives. If no INVITE arrives within the
configured push timeout, the call is ended. See <doc:PushKit>.

### App name and icon

CallKit shows the app name from the Info.plist. Set the icon with
`BaresipCallKitConfiguration.iconTemplateImageData`.
