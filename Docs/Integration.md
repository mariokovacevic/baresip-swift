# Integration guide

## Engine lifecycle

```swift
import BaresipKit

var config = BaresipConfiguration()
config.userAgent = "MyApp/1.0"
config.logLevel = .info
let engine = try BaresipEngine(configuration: config)
engine.setLogHandler(BaresipOSLog.handler(subsystem: "com.example.myapp"))

Task {
    for await event in engine.events {
        switch event {
        case .engine(let state, let error): print(state, error ?? "")
        case .registration(let account, let state, _, let error): print(account, state, error ?? "")
        case .incomingCall(let info, _): print("incoming from", info.remoteURI)
        case .call(let call, let state, let error): print(call, state, error ?? "")
        default: break
        }
    }
}

try await engine.start()
```

States: `idle → starting → ready → running → stopping → stopped`, or `failed`. `stop()` unregisters, waits for the SIP stack to drain (bounded by `timeout`) and joins the engine thread. `start()` after `stop()` creates a fresh engine. One engine per process (baresip is a singleton).

Background and push: call `prepareForPushWakeUp()` from the PushKit handler. If the engine is stopped it starts; if it is running it re-registers every account immediately. `suspend()` marks the engine suspended; `resume()` resets the SIP transports and re-registers. Call `networkDidChange()` from `NWPathMonitor` to reset transports, re-register and update calls with a re-INVITE.

## Accounts and registration

```swift
let account = BaresipAccountConfiguration(
    aor: "sip:1001@pbx.example.com",
    displayName: "Door 1",
    registrar: "sip:pbx.example.com:5061;transport=tls",
    transport: .tls,
    authUser: "1001-auth",
    authPassword: password,
    registerExpires: .seconds(600),
    mediaEncryption: .srtpMandatory,
    nat: BaresipNATConfiguration(mode: .ice,
                                 turnServers: [TURNServer(uri: "turn:turn.example.com:3478?transport=udp",
                                                          username: "u", password: "p")]),
    contactParameters: pushTokens.contactParameters
)
let id = try await engine.addAccount(account)
try await engine.register(accountID: id)
```

`authUser` and the SIP user are independent. The password is copied into the core and wiped when the account is removed; it never appears in logs. Registration events carry a typed `BaresipError` with the SIP status and reason for failures; authentication failures map to `.authentication`, TLS failures to `.tls`, transport problems to `.network`. libre retries with exponential backoff (30 s to 30 min with jitter).

## Push Contact parameters

Parameters are placed inside the Contact URI (`<sip:user@host;app-id=...;pn-tok=...>`). They are validated against the RFC 3261 `paramchar` set; `;` and `=` are not allowed inside values. `:` and `&` pass unchanged, so the Apple combined form `<remote>:remote&<voip>:voip` works as is.

```swift
try await engine.updateContactParameters(accountID: id, parameters: tokens.contactParameters, reregisterNow: true)
```

With `reregisterNow`, a registered account sends a REGISTER with the new Contact immediately and without an unregister; if a REGISTER is in flight the update is applied after its response. The `BaresipKitPushKit` adapter does this automatically when the VoIP token changes. `BaresipEngine.encodeContactParameters` returns the exact string that goes on the wire, for comparison with a reference packet.

## Calls

```swift
let call = try await engine.makeCall(accountID: id, destination: "sip:door@192.0.2.10", video: true)
try await engine.answer(callID: incoming.id, video: incoming.hasVideo)
try await engine.reject(callID: incoming.id, statusCode: 486)
try await engine.hold(callID: call)
try await engine.resume(callID: call)
try await engine.setActiveCall(call)
try await engine.sendDTMF(callID: call, digits: "1234#", duration: .milliseconds(160), gap: .milliseconds(80))
try await engine.setMicrophoneMuted(true, callID: call)
try await engine.transfer(callID: call, to: "sip:2000@pbx.example.com")
let stats = try await engine.callStatistics(callID: call)
```

Call states follow `incoming / outgoingInit / outgoingRinging / earlyMedia / connected / streamsRunning / pausing / paused / resuming / pausedByRemote / updating / ended / failed / released`. `released` is always the last event for a call ID. DTMF uses RTP telephone-event when negotiated, otherwise SIP INFO (`dtmfMode: .auto`); the DTMF event reports which one was used. After a resume the core requests a video keyframe and emits `.media(.keyframeRequested)`.

## Audio session

The core never touches `AVAudioSession`. Audio I/O for a call starts only after `audioSessionDidActivate()` and stops at `audioSessionDidDeactivate()`. With CallKit, `BaresipCallKitAdapter` calls these from `provider(_:didActivate:)` and `didDeactivate`. Without CallKit, use `BaresipAudioSessionController`:

```swift
let audio = BaresipAudioSessionController(engine: engine)
try audio.configureForVoIP(allowBluetooth: true)
try await audio.activate()
try audio.setSpeakerEnabled(true)
```

Route changes and interruptions are forwarded automatically. Echo cancellation, noise suppression and AGC come from the VoiceProcessingIO audio unit (`audio.voiceProcessing = true`).

## CallKit

```swift
let callKit = BaresipCallKitAdapter(engine: engine, configuration: BaresipCallKitConfiguration(supportsVideo: true))
let uuid = try await callKit.startOutgoingCall(to: "sip:door@192.0.2.10", video: true)
```

Incoming early media (preview before answering, for example at a door intercom): `sendProgress(callID:earlyVideo:)` answers the INVITE with 183 Session Progress and receives the caller's audio, and video when `earlyVideo` is true, while the call is still ringing. During the preview the local direction is receive-only, so the caller does not hear or see you; answering switches both directions back to send and receive. `answerEarlyMedia: true` on the account does the same automatically for incoming calls, except while another call is active (a waiting call is not previewed over the current conversation). If answering fails, the preview directions are restored, so nothing is sent before the call is really answered. CallKit activates the audio session only after the user answers, so to hear the caller during a preview the app activates the session itself (`BaresipAudioSessionController.activate()`), as the sample app does; video preview needs no audio session. The `.incomingCall` event tells whether the caller offered early video. The call state is `earlyMedia` until you answer or reject.

Incoming calls are reported to CallKit when the INVITE arrives. After a VoIP push, report the call first with `reportIncomingCallFromPush(uuid:remoteURI:displayName:hasVideo:)`; when the INVITE arrives it is matched to that UUID by caller user and host (a push without a caller matches the next INVITE) and, if the user already answered, answered immediately; if no INVITE arrives within `pushInviteTimeout` (30 s by default) the CallKit call is ended. Answering from the CallKit UI keeps video when the call offers it. Hold, mute, DTMF and end actions are forwarded to the engine. Outgoing progress is reported from `outgoingRinging`/`earlyMedia` (connecting) and `connected` (connected).

## Messages

```swift
let id = try await engine.sendMessage(to: "sip:bob@pbx.example.com", text: "Hello")
for await event in engine.events {
    switch event {
    case .messageStatus(let status) where status.id == id:
        print(status.delivered ? "delivered" : "failed: \(String(describing: status.error))")
    case .message(let message):
        print("\(message.from): \(message.text ?? "")")
    default: break
    }
}
```

`sendMessage` sends a SIP MESSAGE (RFC 3428) with `text/plain` from the given or default account; `.messageStatus` reports the final response (delivered on 2xx, otherwise the SIP status or transport error). Incoming `text/plain` and `application/json` messages arrive as `.message` with the raw body; other content types are answered with 415 by baresip.

## Recording

```swift
try await engine.startRecording(callID: call, to: fileURL)
try await engine.stopRecording(callID: call)
```

Writes a 16-bit PCM stereo WAV: left is your microphone as sent, right is the other party as played, at the call's audio sample rate. Recording survives hold, resume and re-INVITEs, and the file is finished when you stop or when the call ends; `.media(.recordingStarted)` and `.media(.recordingStopped)` report it. Tell the other party that the call is recorded where the law requires it.

## Transfers

`transfer(callID:to:)` is a blind transfer (REFER). For an attended transfer put the first call on hold, call the target, talk to it, then call `transferAttended(callID: firstCall, to: consultationCall)`: the first party receives a REFER with `Replaces` and calls the target, the target's call is replaced without ringing, and both of your calls end. When the other side transfers you, the SDK follows the REFER automatically (a new outgoing call appears as `.call(newID, .outgoingInit)` and the old call ends when the transfer succeeds); set `acceptTransfers: false` on the account to decline transfers with 603.

## PushKit

```swift
let push = BaresipPushKitAdapter(engine: engine, appID: "com.example.myapp", accountID: id) { payload in
    try await callKit.reportIncomingCallFromPush(uuid: UUID(), remoteURI: payload["from"] as? String, displayName: nil, hasVideo: false)
}
push.updateRemoteToken(apnsToken)
```

The adapter only transports token information into SIP; it never sends pushes. iOS requires every VoIP push to be reported to CallKit: let the handler throw when it cannot report the call, and the adapter then reports and immediately ends a placeholder call so the system does not terminate the app.

## Video

```swift
let remoteView = BaresipVideoView()
try await engine.setVideoRenderer(remoteView.renderer, callID: call)
let localView = BaresipVideoView()
try await engine.setVideoRenderer(localView.renderer, callID: call, local: true)
try await engine.startVideoPreview(device: "front", renderer: localView.renderer)
try await engine.setCamera("back", callID: call)
try await engine.setVideoEnabled(false, callID: call)
```

H.264 (`packetization-mode=1`, baseline `42e01f`) is encoded and decoded by VideoToolbox; VP8 is available with `MODULE_SET=full`. Frames reach renderers on media threads as `CVPixelBuffer`s. Frames decoded by VideoToolbox and camera frames are the original buffers, without a copy (retain one if you keep it past the callback); VP8 and other software frames are copied into a new buffer. RTCP NACK, PLI and FIR are handled by baresip.

## TLS

Verification is on by default with TLS 1.2 as the minimum. Provide a private CA in memory with `tls.caCertificatesPEM`; pin SPKI SHA-256 hashes (base64, the same format as HPKP) with `tls.pinnedSPKISHA256`; a connection is accepted only when the chain verifies and at least one certificate matches a pin. `verifyServer = false` exists only behind `BaresipTLSConfiguration.insecureSkippingServerVerification()` in DEBUG builds.

Compute a pin:

```bash
openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
```

## ICE, STUN, TURN

`nat.mode` selects `.none` (symmetric RTP/latching, for deployments with a server-side media relay), `.stun` or `.ice`. `BaresipConfiguration.iceRelayOnly` restricts ICE to relayed candidates for every call (useful to hide the device address or to force a known media path); it is an engine-wide setting because baresip applies the ICE policy globally. TURN works inside ICE over UDP (`turn:host:3478`), TCP (`turn:host:3478?transport=tcp`) and TLS (`turns:host:5349`, verified against the CA configured in `tls`, and subject to the same pins). With TCP or TLS the call uses relayed candidates only, which is what networks that block UDP need. `.ice(...)` events report gathering, checking, connected (with local and remote candidate types and addresses) and failed; `callStatistics` carries the same selected pair.

Video bitrate adapts to packet loss by default (`BaresipConfiguration.videoAdaptiveBitrate`): every second the SDK reads the RTCP receiver reports for the video stream, lowers the encoder target when more than 10 % of the packets were lost and raises it slowly while loss stays under 2 %, between `videoMinimumBitrate` and `video.bitrate`. `setVideoMaxBitrate(callID:bitsPerSecond:)` caps one call (for example on a cellular link or when the app goes to Picture in Picture); `nil` removes the cap. `callStatistics(callID:)` reports the current target as `videoTargetBitrate`.

ICE restarts on network changes: when `networkDidChange(updateCalls: true)` finds that a call's local address changed, ICE calls restart ICE with new credentials and freshly gathered candidates and re-INVITE once gathering is done (calls without ICE get the plain re-INVITE with the new address). `restartICE(callID:)` restarts ICE for one call on demand; without a network change it keeps the gathered candidates and TURN allocations and only renews the credentials. A peer's ICE restart is answered with new credentials. Media pauses while the new candidates are checked. Asterisk (checked with 23.5) only restarts its ICE session when the candidates change as well, so `restartICE(callID:)` without a network change fails against Asterisk; restarts caused by an address change work.

## Logging

`setLogHandler` receives every core, SIP and media line with level and domain; `logSIPTrace` adds the full SIP messages. Digest responses, `pn-tok` values (after an 8-character prefix), passwords and STUN passwords are redacted before the handler is called.
