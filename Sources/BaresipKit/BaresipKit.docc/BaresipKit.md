# ``BaresipKit``

SIP voice and video calls on iOS, built on baresip.

## Overview

BaresipKit runs the baresip user agent on its own thread and exposes it as ``BaresipEngine``:
an `async` API for accounts, calls and media, and an `AsyncStream` of ``BaresipEvent`` values
for everything that happens afterwards. Optional modules connect the engine to the system:
`BaresipKitAudio` for the audio session, `BaresipKitVideo` for video views, and
`BaresipKitCallKit` and `BaresipKitPushKit` for the system call screen and VoIP pushes.

## Topics

### Essentials

- <doc:GettingStarted>
- ``BaresipEngine``
- ``BaresipConfiguration``
- ``BaresipEvent``

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
- ``BaresipPixelFormat``

### Network

- ``BaresipTLSConfiguration``
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
- <doc:PushKit>

### Diagnostics

- ``BaresipError``
- ``BaresipStatus``
- ``BaresipCallStatistics``
- ``BaresipStreamStatistics``
- ``BaresipLogEntry``
- ``BaresipLogLevel``
- ``BaresipLogDomain``
- ``BaresipLogHandler``
- ``BaresipOSLog``
- ``BaresipDiagnosticEvent``
- ``BaresipEngineState``
