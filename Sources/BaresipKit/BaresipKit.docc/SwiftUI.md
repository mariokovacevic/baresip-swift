# SwiftUI

Show registrations and calls in SwiftUI without handling events yourself.

## Overview

`BaresipPhone` from the `BaresipKitSwiftUI` module turns the engine's events into published
state: the registration state of every account and a list of calls. Each call is a
`BaresipPhoneCall` with its state, the other side, mute and hold, and the actions a call
screen needs. Both are `ObservableObject`s, so they work from iOS 16.

```swift
import BaresipKit
import BaresipKitSwiftUI

struct PhoneView: View {
    @StateObject private var phone: BaresipPhone

    init(engine: BaresipEngine) {
        _phone = StateObject(wrappedValue: BaresipPhone(engine: engine))
    }

    var body: some View {
        List(phone.calls) { call in
            CallRow(call: call)
        }
        .task { await phone.run() }
    }
}

struct CallRow: View {
    @ObservedObject var call: BaresipPhoneCall

    var body: some View {
        HStack {
            Text(call.remoteDisplayName.isEmpty ? call.remoteURI : call.remoteDisplayName)
            Spacer()
            Button(call.isMuted ? "Unmute" : "Mute") {
                Task { try? await call.setMuted(!call.isMuted) }
            }
            Button("Hang up") {
                Task { try? await call.hangUp() }
            }
        }
    }
}
```

Create the phone once per engine and keep it: `StateObject(wrappedValue:)` in the view's
initializer creates it only the first time the view appears. Do not pass a new `BaresipPhone`
to a view on every update.

`run()` applies events until its task is cancelled; with `.task` that is when the view goes
away. Each run first brings the call list in line with the engine: calls that ended or started
while no view was shown are removed or added, and calls the phone already tracks get their
current state and details, so a call that was answered in the meantime no longer shows as
incoming. The phone neither starts nor stops the engine, and works next to code that reads
``BaresipEngine/events`` directly, because every subscriber receives every event.

`registrations` starts from the accounts the engine has when `run()` begins and then follows
the registration events, so an account that registered before the first run is shown too.

Place a call through the phone so it appears in the list at once:

```swift
let call = try await phone.makeCall(to: "sip:bob@example.com", video: true)
```

`incomingCall` is the first call that rings on this side and is not answered yet; a call whose
direction is not known yet is never treated as incoming. A call stays in `calls` until the
engine releases it, so a view can still show why a call failed through `error`.

`state` comes from the engine's events, and from the engine's own view of the call each time
`run()` starts. The other properties, such as `isMuted`, `audioCodec` or `videoDirection`, are
read from the engine after every state and media change.
`isOnHold` covers putting the call on hold and resuming it; `isHeldByRemote` is true while the
other side holds the call.

### The active call

`activeCall` is the call a call screen shows. The first call that appears becomes active; a call
placed with `makeCall` becomes active unless an established call is, and a call answered with
`answer`, or on the system call screen, becomes active. `makeActive(_:)` switches to another
call; the engine puts the others on hold. When the active call ends, the next call becomes
active, a held one first, and is resumed. Set `resumesHeldCallWhenActiveCallEnds` to `false`
to leave it on hold.

### Video and the camera

`isSendingVideo` says whether your camera is sent: what the call was placed or answered with,
and after that what `setVideoEnabled(_:)` and the negotiation decided. `isReceivingVideo` says
whether the other side's video arrives. `camera` is the camera in use; `setCamera(_:)` and
`switchCamera()` change it.

`BaresipCallVideo(call:source:)` shows the remote video or your camera, and `BaresipSelfView`
is the small picture of your own camera that call screens put in a corner: it appears while the
camera is sent, mirrors the front camera and switches cameras when tapped.

```swift
ZStack {
    if call.isReceivingVideo {
        BaresipCallVideo(call: call)
            .ignoresSafeArea()
    }
    CallControls(call: call)
}
.overlay(alignment: .topTrailing) {
    BaresipSelfView(call: call)
        .padding()
}
```

Use `BaresipCallVideo(engine:callID:source:mirrored:videoGravity:)`, or `BaresipVideoView`
directly, for a different look.

### CallKit

Pass the CallKit adapter as the phone's call controller, and the calls' actions go through
CallKit for the calls it shows, so the system call screen stays in step and CallKit activates
the audio session:

```swift
let callKit = BaresipCallKitAdapter(engine: engine, configuration: BaresipCallKitConfiguration())
let phone = BaresipPhone(engine: engine, callController: callKit)
```

Leave it `nil` in the simulator, where CallKit never activates the audio session, or to call
the engine yourself. Muting on the system call screen updates `isMuted`.

### Early media and DTMF

`startPreview(video:audio:)` shows and plays a ringing call before it is answered; the caller
does not see or hear you. `sendDTMF(_:expectingReply:timeout:)` sends a code and waits for the
digit a door station sends back when the door opened. `receivedDTMF` collects the digits the
other side sent.
