# ``BaresipKit``

SIP voice and video calls on iOS, built on baresip.

## Overview

> Important: BaresipKit is in beta. It has no release yet, and the API can still change.

BaresipKit runs the baresip user agent on its own thread and exposes it as ``BaresipEngine``:
an `async` API for accounts, calls and media, and an `AsyncStream` of ``BaresipEvent`` values
for everything that happens afterwards. Optional modules connect the engine to the system:
`BaresipKitAudio` for the audio session, `BaresipKitVideo` for video views, and
`BaresipKitCallKit` or `BaresipKitLiveCommunication` and `BaresipKitPushKit` for the system
call screen and VoIP pushes, and
`BaresipKitSwiftUI` for observable registration and call state.

Enumerations such as ``BaresipEvent``, ``BaresipCallState`` and ``BaresipError/Code`` can gain
cases in a minor release, so end a `switch` over them with `default:`. What Semantic Versioning
covers is in [Stability](https://github.com/mariokovacevic/baresipkit/blob/main/Docs/STABILITY.md).

## Topics

### Essentials

- <doc:GettingStarted>
- ``BaresipEngine``
- ``BaresipConfiguration``
- ``BaresipEvent``
- ``BaresipAppLifecycle``

### Accounts

- ``BaresipAccountConfiguration``
- ``BaresipAccountID``
- ``BaresipRegistrationState``
- ``BaresipTransport``
- ``BaresipContactParameter``
- <doc:PushContactParameters>

### Calls

- ``BaresipCallID``
- ``BaresipCallState``
- ``BaresipCallInfo``
- ``BaresipDTMFMode``
- ``BaresipDTMFEvent``
- ``BaresipTransferEvent``
- ``BaresipCallController``

### Media

- <doc:AudioSession>
- <doc:Video>
- ``BaresipAudioConfiguration``
- ``BaresipVideoConfiguration``
- ``BaresipMediaEncryption``
- ``BaresipMediaDirection``
- ``BaresipMediaEvent``
- ``BaresipMediaEventInfo``
- ``BaresipAudioEvent``
- ``BaresipVideoRenderer``
- ``BaresipVideoFrame``
- ``BaresipCameraPosition``
- ``BaresipPixelFormat``

### Network

- <doc:NetworkChanges>
- <doc:TLSAndCertificates>
- <doc:NATTraversal>
- ``BaresipTLSConfiguration``
- ``BaresipCertificates``
- ``BaresipCertificateError``
- ``BaresipNetworkMonitor``
- ``BaresipNetworkPath``
- ``BaresipNATConfiguration``
- ``BaresipNATTraversal``
- ``BaresipTURNServer``
- ``BaresipICEState``
- ``BaresipICEEvent``
- ``BaresipCandidateType``
- ``BaresipNetworkEvent``

### Messaging

- ``BaresipMessage``
- ``BaresipMessageID``
- ``BaresipMessageStatus``

### System integration

- <doc:CallKit>
- <doc:LiveCommunicationKit>
- <doc:PushKit>
- <doc:SwiftUI>

### Diagnostics

- ``BaresipError``
- ``BaresipCallStatistics``
- ``BaresipStreamStatistics``
- ``BaresipLogEntry``
- ``BaresipLogLevel``
- ``BaresipLogDomain``
- ``BaresipLogHandler``
- ``BaresipOSLog``
- ``BaresipFileLog``
- ``BaresipDiagnosticEvent``
- ``BaresipEngineState``
