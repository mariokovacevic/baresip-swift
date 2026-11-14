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
try await callKit.setOnHold(true, uuid: uuid)
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
    uuid: nil,
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
> route. Better still, let the server name the call; see the next section.

### A call UUID from the server

Matching by caller is a guess: two calls from one caller, or a push that names no caller, can
bind the wrong INVITE. A server that sends both the push and the INVITE can name the call
instead. It creates a UUID per call, puts it in the push payload and in a header of the INVITE,
and the app passes both on:

```swift
var configuration = BaresipCallKitConfiguration(supportsVideo: true)
configuration.callUUIDHeader = "X-Call-UUID"
let callKit = BaresipCallKitAdapter(engine: engine, configuration: configuration)

let uuid = (payload["uuid"] as? String).flatMap(UUID.init(uuidString:))
callKit.reportIncomingCallFromPush(uuid: uuid, remoteURI: payload["from"] as? String,
                                   displayName: nil, hasVideo: false) { _ in }
```

An INVITE with the header is then bound to the pushed call with that UUID, whoever its caller
is, and no other push that named a UUID takes it. A push whose payload has no UUID (`uuid` is
`nil`) is matched by its caller, also with an INVITE that carries the header, so a server that
sometimes leaves the UUID out of the push does not ring the call twice. The INVITE rings as a
call of its own when no push matches it. When
the INVITE arrives first, it is reported under the UUID from its header, so the push that
follows is recognized. A push with the UUID of a call that waits, rings or runs already, for
example one the server sent twice, is reported under a new UUID and ended at once, because
CallKit refuses a second call with a UUID it knows. An INVITE without the header is matched by
its caller as described above.

The UUID names the call the caller made, not one leg of it. A queue, hunt group or ring group
that sends a new INVITE for every attempt, or for every phone it rings, must put the same UUID
in the push and in each of those INVITEs: the UUID of the incoming call, not of the channel to
the phone. An INVITE with a UUID no push named rings as a call of its own, and the pushed call
waits for its INVITE until `pushInviteTimeout`.

The UUID is random and travels only in the push and in the INVITE, so an INVITE from someone
else cannot take a pushed call's place without it. `Tools/DoorStack` shows the server side: the
dialplan creates the UUID, the push gateway sends it as `uuid`, and the INVITE carries it as
`X-Call-UUID`.

### Recents and calling again

Calls appear in the Recents list of the Phone app; set
`BaresipCallKitConfiguration.includesCallsInRecents` to `false` to keep them out. A tap on such
an entry opens the app with a request to call again. Declare `INStartCallIntent` under
`NSUserActivityTypes` in the Info.plist and place the call:

```swift
ContentView()
    .onContinueUserActivity(BaresipRedialRequest.activityType) { activity in
        guard let request = BaresipRedialRequest(activity: activity) else { return }
        Task { try await phone.makeCall(to: request.destination, video: request.video) }
    }
```

The destination is what the adapter gave CallKit for the earlier call. The request can arrive
while the app starts, before the account is registered; keep it until then. Without this
handling a tap in Recents opens the app and nothing happens, which is a reason to turn the
option off.

### Callers with phone numbers

By default every caller is reported to CallKit as a generic handle with the SIP URI. With

```swift
configuration.handleStyle = .phoneNumberWhenNumeric
```

a caller whose user part is a number, such as `sip:100@pbx.example.com` or
`sip:+15555550100@pbx.example.com`, is reported as the phone number `100` or `+15555550100`.
iOS then shows the name and photo of a contact with that number on the call screen and in
Recents, and a redial request carries the number, which the app turns into a SIP URI for its
server. Other callers, such as `sip:door1@pbx.example.com`, stay generic handles. The same
applies to the destination of an outgoing call.

### Calls answered on another phone

When several phones ring for one call, such as every resident of a flat for a ring from the
door, the server cancels the others once one answers and usually says so in the CANCEL with
`Reason: SIP;cause=200;text="Call completed elsewhere"` (RFC 3326). The adapter then ends the
call as answered elsewhere, so it is not listed as missed; with `cause=600` or `603` it ends it
as declined elsewhere. The ended event carries the same in ``BaresipError/endReason``.

### Calls the server replaces or transfers

A call can go on in a new SIP call after it was answered. Servers replace an established call
with an INVITE that carries `Replaces` (RFC 3891) for call pickup, queues, parking and attended
transfers, and the other side can transfer a call with REFER (RFC 3515), which the engine
follows by calling the transfer target. The new call's ``BaresipCallInfo/replacesCallID`` names
the old call, and the old call ends with ``BaresipCallEndReason/replaced``.

The adapter moves the CallKit call to the new call: it neither ends the CallKit call nor rings
again, so the call screen, the audio session and Bluetooth stay as they were, and only the
caller shown changes. An INVITE with `Replaces` is answered at once. If no new call takes over
within five seconds, the CallKit call ends.

### Actions that time out

CallKit gives the app a limited time to carry out an action. When the engine does not finish in
time, the adapter gives up on it: whoever waits for the action, for example in
`setOnHold(_:uuid:)`, gets `BaresipCallKitError.actionTimedOut`. CallKit fails a call whose start
or answer timed out, so the adapter ends the engine's side as well: an outgoing call is hung up
as soon as the engine has placed it, and an incoming one at once.

A request that CallKit accepts but never carries out also ends with `actionTimedOut` after a
minute, so a caller of `placeCall(to:video:)` or of an action method never waits forever. When
CallKit resets the provider, every pending request fails with
`BaresipCallKitError.providerReset`, and every call is hung up.

### App name and icon

CallKit shows the app name from the Info.plist. Set the icon with
`BaresipCallKitConfiguration.iconTemplateImageData`.
