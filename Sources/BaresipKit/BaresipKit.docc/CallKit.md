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

### An in-app incoming call screen

When the app shows its own incoming call screen as well, answer and decline through CallKit so
the system screen stops ringing and CallKit activates the audio session:

```swift
if let uuid = callKit.uuid(for: call) {
    try await callKit.answerCall(uuid: uuid)   // or endCall(uuid:) to decline
}
```

When the user answers or declines on the system screen instead, the engine's call events
report it: the call becomes `connected`, or `ended` and `released`. Update the app's screen
from those events.

### Mute, hold and the camera

Mute and hold through the adapter, so the system call screen and the app show the same state:

```swift
try await callKit.setMuted(true, uuid: uuid)
try await callKit.setHeld(true, uuid: uuid)
callKit.setMuteHandler { call, muted in
    print("call", call, "muted:", muted)
}
```

These methods, and `answerCall(uuid:)` and `endCall(uuid:)`, return once the adapter carried the
action out on the engine, and throw the engine's error when it failed there. The handler reports
mute changes made on the system screen. By default, answering on the system
screen sends the camera when the call has video. Set
`BaresipCallKitConfiguration.sendsCameraOnAnswer` to `false` to receive the caller's video with
the camera off; turn it on later with ``BaresipEngine/setVideoEnabled(_:callID:)``.

### One place for call actions

The adapter is a ``BaresipCallController``: `placeCall(to:video:)`, `answer(_:video:)`,
`end(_:)`, `setOnHold(_:call:)` and `setMuted(_:call:)` take engine call identifiers instead of
CallKit UUIDs, and `answer(_:video:)` sends the camera as the app asks. Give the adapter to
`BaresipPhone` from `BaresipKitSwiftUI`, and its calls use CallKit for every call CallKit
shows and the engine otherwise; see <doc:SwiftUI>. `addMuteObserver(_:)` adds observers next to
the mute handler.

### Calls announced by a push

After a VoIP push, report the call before the INVITE arrives. iOS expects the report before the
PushKit delegate method returns, so use the variant with a completion handler there: it has
handed the call to CallKit when it returns.

```swift
callKit.reportIncomingCallFromPush(
    uuid: UUID(),
    remoteURI: "sip:bob@example.com",
    displayName: "Bob",
    hasVideo: false
) { error in
    if let error {
        print("CallKit refused the call:", error)
    }
}
```

CallKit refuses a call during Do Not Disturb or from a blocked caller. The pushed call is then
forgotten, and nothing waits for its INVITE. Outside a PushKit delegate method there is an
`async` variant without the completion handler, which throws the CallKit error.

The INVITE that follows is bound to the oldest pushed call it matches:

- A push with the caller's user and host matches an INVITE from that user and host.
- A push with only a user, such as `100`, matches an INVITE from that user on any host.
- A push without a caller matches the next INVITE, whoever sends it. Set
  `BaresipCallKitConfiguration.matchesPushWithoutCaller` to `false` to turn this off: such a
  pushed call then ends after the push timeout, and the INVITE is reported as a call of its own.

A match on user and host wins over a match on the user alone, and both win over a push without
a caller. Once an INVITE is bound, CallKit is updated with the INVITE's own URI and display
name, so the system call screen shows the SIP peer. The name from the push stays only when the
INVITE has no display name and comes from exactly the pushed user and host.

If the user has already answered, the call is answered as soon as it arrives. The camera is
then sent only when the push announced video, the INVITE offers video and
`sendsCameraOnAnswer` is `true`. If no INVITE arrives within
`BaresipCallKitConfiguration.pushInviteTimeout`, the call is ended. See <doc:PushKit>.

A push and its INVITE can arrive in either order, and the user can act in between:

- When the user declines the pushed call before its INVITE arrives, the INVITE is rejected with
  486 Busy Here instead of ringing again. A declined push is remembered for the push timeout.
- When the INVITE arrives first, for example while the app is in the foreground, the call is
  already ringing under its own UUID when the push comes. iOS still requires a reported call
  for the push, so the adapter reports the UUID you passed and ends it at once as answered
  elsewhere. The ringing call is not touched; ask for its UUID with `uuid(for:)`.

> Important: The `From` header of an INVITE is not authenticated, so a match shows who the
> INVITE claims to be from, not who sent it. Someone who can send an INVITE to the device while
> a pushed call waits, and who knows or guesses the caller, takes that call's place, and is
> answered at once when the user already tapped Answer. To narrow this, put the caller's full
> SIP URI in every push, set `matchesPushWithoutCaller` to `false`, and let only your SIP
> server reach the device: register over TLS and use a server that drops INVITEs it did not
> route.

### App name and icon

CallKit shows the app name from the Info.plist. Set the icon with
`BaresipCallKitConfiguration.iconTemplateImageData`.
