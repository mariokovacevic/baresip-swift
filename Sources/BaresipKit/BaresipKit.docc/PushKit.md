# PushKit

Receive calls while the app is not running.

## Overview

`BaresipPushKitAdapter` from the `BaresipKitPushKit` module registers for VoIP pushes, sends
the push token to the registrar as `Contact` parameters, and wakes the engine when a push
arrives. The adapter never sends pushes; the SIP server or a push proxy does, using the
parameters described in <doc:PushContactParameters>.

```swift
import BaresipKitPushKit

let push = BaresipPushKitAdapter(engine: engine, appID: "com.example.app", accountID: account) { payload in
    callKit.reportIncomingCallFromPush(
        uuid: UUID(),
        remoteURI: payload["from"] as? String,
        displayName: nil,
        hasVideo: false
    ) { _ in }
}
push.updateRemoteToken(apnsToken)
```

### Report the call before the handler returns

iOS terminates an app that receives a VoIP push and returns from the PushKit delegate method
without a call reported to CallKit. The adapter therefore calls the handler inside the delegate
method, on the main queue, and the handler must report the call before it returns: it is not
`async`, and it must not start a `Task` for the report.
`reportIncomingCallFromPush(uuid:remoteURI:displayName:hasVideo:completion:)` of
`BaresipCallKitAdapter` has handed the call to CallKit when it returns; its completion handler
tells later whether CallKit accepted the call.

Throw from the handler when you cannot report a call, for example because the CallKit adapter
does not exist yet. The adapter then reports a placeholder call and ends it at once, still inside
the delegate method. The placeholder uses a provider of its own that keeps the call out of the
Recents list and is invalidated when the call has ended. When CallKit itself refuses your
report, for example during Do Not Disturb, the call was reported as far as iOS is concerned and
no placeholder is needed.

When a push launches the app, iOS delivers it as soon as a push registry exists, so create the
adapter and the objects its handler needs early, in
`application(_:didFinishLaunchingWithOptions:)`.

### Waking the engine

After the handler returns, the adapter calls ``BaresipEngine/prepareForPushWakeUp()``. What that
does depends on the engine:

- A running engine is no longer marked as suspended and sends a REGISTER for every account that
  registers, so the server learns the current address and can deliver the INVITE.
- An engine that is idle, stopped or failed is started. It has no accounts then, because
  stopping an engine removes them: nothing registers until you add the account and register it
  again, as after a normal start.

So keep the engine running while the app lives, and after a launch by a push create the engine,
add the account and register in your launch code as usual. The pushed call waits for its INVITE
for `BaresipCallKitConfiguration.pushInviteTimeout`.

### Tokens and other Contact parameters

The adapter sends the account's `Contact` parameters to the engine whenever the VoIP token, the
APNs token from `updateRemoteToken(_:)`, the `app-id` or the bound account changes. Updates are
sent one after the other, and an update that is overtaken while another is on its way is
skipped, so the registrar always ends up with the latest state.

The adapter owns the `Contact` parameters of the bound account: each update replaces all of
them, including those set in ``BaresipAccountConfiguration/contactParameters``. Give the adapter
the parameters the account needs besides the push ones, and it sends them together:

```swift
let push = BaresipPushKitAdapter(
    engine: engine,
    appID: "com.example.app",
    additionalContactParameters: [BaresipContactParameter("x-device", "door-1")]
) { payload in
    callKit.reportIncomingCallFromPush(uuid: UUID(), remoteURI: payload["from"] as? String,
                                       displayName: nil, hasVideo: false) { _ in }
}
push.updateAdditionalContactParameters([BaresipContactParameter("x-device", "door-2")])
```

An additional parameter with the name of a push parameter, such as `pn-tok`, is left out.

### Errors

The adapter works on its own when a token changes or a push arrives, so its errors have no
caller to return to. Set a handler to learn about them:

```swift
push.setErrorHandler { step, error in
    print("push adapter:", step, error)
}
```

`step` is `contactParameters` when the engine refused an update, for example because the account
no longer exists, `incomingPush` when your push handler threw and a placeholder call was
reported, and `engineWakeUp` when the engine could not be woken after a push.

### Changing the app-id

`updateAppID(_:)` changes the `app-id` parameter, for example to switch between the sandbox and
production push environments, and registers the account again with it.

### Requirements

- The `voip` background mode and the Push Notifications capability.
- A VoIP push certificate or token-based APNs key on the push sender.
- A SIP server or proxy that sends a push when a call arrives for a registered device.
