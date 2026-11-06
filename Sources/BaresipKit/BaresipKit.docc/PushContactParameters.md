# Push Contact Parameters

Tell the registrar how to reach the device with a push.

## Overview

Push-capable SIP servers learn the device's push token from parameters in the `Contact` URI of
REGISTER requests, as described in RFC 8599. ``BaresipAccountConfiguration/contactParameters``
sets them when the account is added, and
``BaresipEngine/updateContactParameters(accountID:parameters:reregisterNow:)`` replaces them,
for example when the token changes:

```swift
try await engine.updateContactParameters(
    accountID: account,
    parameters: [
        BaresipContactParameter("pn-provider", "apns"),
        BaresipContactParameter("pn-prid", voipTokenHex),
        BaresipContactParameter("pn-param", "TEAMID.com.example.app.voip"),
    ],
    reregisterNow: true
)
```

With `reregisterNow`, a registered account sends a REGISTER with the new parameters right away,
without unregistering first.

`BaresipPushTokens` in the `BaresipKitPushKit` module builds the parameter set used by servers
such as Flexisip (`app-id`, `pn-type`, `pn-tok`, `pn-silent`, `pn-timeout`), and
`BaresipPushKitAdapter` keeps it current.

### Validation

Names and values must be SIP tokens. `;`, `=`, spaces and other separators are rejected, while
`:` and `&` pass unchanged, so a combined token such as `<remote>:remote&<voip>:voip` works.
``BaresipEngine/encodeContactParameters(_:)`` returns the exact text that goes into the
`Contact` header, which is useful to compare with a packet capture.

### Privacy

The core redacts `pn-tok`, `pn-prid` and `pn-voip-tok` values in logs, keeping only the first
eight characters.
