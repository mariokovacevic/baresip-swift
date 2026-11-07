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
    try await callKit.reportIncomingCallFromPush(
        uuid: UUID(),
        remoteURI: payload["from"] as? String,
        displayName: nil,
        hasVideo: false
    )
}
push.updateRemoteToken(apnsToken)
```

iOS terminates an app that receives a VoIP push without reporting a call to CallKit. Report the
call in the handler, and throw when you cannot: the adapter then reports and immediately ends a
placeholder call.

After the handler returns, the adapter calls ``BaresipEngine/prepareForPushWakeUp()``, which
starts the engine if needed and registers every account again so the INVITE can arrive.

### Requirements

- The `voip` background mode and the Push Notifications capability.
- A VoIP push certificate or token-based APNs key on the push sender.
- A SIP server or proxy that sends a push when a call arrives for a registered device.
