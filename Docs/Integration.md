# Integration guide

The full integration guide for the Swift package on iOS and macOS; start with
[iOS.md](iOS.md). For Android, see [Android.md](Android.md).

## Engine lifecycle

```swift
import BaresipKit

var config = BaresipConfiguration(instanceUUID: installID)
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

States: `idle → starting → ready → running → stopping → stopped`, or `failed`. `stop()` ends every call, unregisters, waits for the SIP stack to drain (bounded by `timeout`) and joins the engine thread. Its accounts are gone afterwards: `start()` after `stop()` gives an engine without accounts, so add them again. Several engines may exist, but only one may run per process (baresip keeps global state); starting a second one fails with `.busy`.

Background and push: call `prepareForPushWakeUp()` when a VoIP push arrives. If the engine is stopped it starts, without accounts; if it is running, every account that is registered or registering sends a REGISTER right away. An account you unregistered stays unregistered. `suspend()` has no effect in this release: transports, registrations and calls stay as they are. `resumeFromBackground()` resets the SIP transports and re-registers, whether or not `suspend()` was called. Call `networkDidChange()` from `NWPathMonitor`: the engine reads the local addresses again, resets the transports, re-registers and updates calls with a re-INVITE. This also brings up an engine that was started without a network.

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
                                 turnServers: [BaresipTURNServer(uri: "turn:turn.example.com:3478?transport=udp",
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
try await engine.blindTransfer(callID: call, to: "sip:2000@pbx.example.com")
let stats = try await engine.callStatistics(callID: call)
```

Call states follow `incoming / outgoingInit / outgoingRinging / earlyMedia / connected / streamsRunning / pausing / paused / resuming / pausedByRemote / updating / ended / failed / released`. `released` is always the last event for a call ID. DTMF uses RTP telephone-event when negotiated, otherwise SIP INFO (`dtmfMode: .auto`); the DTMF event reports which one was used. After a resume the core requests a video keyframe and emits `.media(.keyframeRequested)`.

Every call negotiates video: `video: false` means the camera is not sent, while the other side's picture, such as a door station's camera, is still received. `makeCall(...audio: false)` and `answer(callID:video:audio: false)` leave the audio inactive, for watching a camera or sending a door-opening DTMF code without opening the microphone. Headers named in the account's `incomingHeaders`, such as `X-Device-ID`, are kept from incoming INVITEs and read with `incomingHeader(_:callID:)`. `BaresipCallInfo.isMicrophoneMuted` is the real mute state.

Calls use SIP session timers (RFC 4028) by default: `BaresipConfiguration.sessionTimer` (30 minutes) is offered in every INVITE and accepted from a caller that supports session timers, so providers and PBXs that require them, or that end calls nobody refreshes, keep the call up. The side that refreshes renews the session at half the interval with an UPDATE without a body, or with a re-INVITE without an offer when the other side does not allow UPDATE; the other side hangs up with BYE when the session is not renewed in time. A 422 from the other side raises the interval to its `Min-SE` and the INVITE is sent again. `sessionTimer = nil` turns session timers off; `minimumSessionTimer` (90 seconds) must be at least 90 seconds, the minimum of RFC 4028, and must not be longer than `sessionTimer`; creating the engine fails with other values.

## Audio session

The core never touches `AVAudioSession`. Audio I/O for a call starts only after `audioSessionDidActivate()` and stops at `audioSessionDidDeactivate()`. With CallKit, `BaresipCallKitAdapter` calls these from `provider(_:didActivate:)` and `didDeactivate`. Without CallKit, use `BaresipAudioSessionController`:

```swift
let audio = BaresipAudioSessionController(engine: engine)
try audio.configureForVoIP(allowBluetooth: true)
try await audio.activate()
try audio.setSpeakerEnabled(true)
```

Route changes are forwarded automatically when a device appeared or went away. An interruption pauses the engine's audio. When it ends, the controller resumes only if iOS reports `shouldResume`: it first activates the session again when `activate()` had activated it, waits for the next `didActivateFromCallKit()` when CallKit had, and otherwise resumes the engine and leaves the session to its owner. Without `shouldResume` the audio stays paused until `activate()` is called again. After a reset of the media services the controller applies the `configureForVoIP` category again and restarts the engine's audio. `availableOutputs`, `currentOutput` and `selectOutput(_:)` choose where call audio plays: earpiece, loudspeaker, wired headphones, Bluetooth or car audio. Echo cancellation, noise suppression and AGC come from the VoiceProcessingIO audio unit (`audio.voiceProcessing = true`).

## CallKit

```swift
let callKit = BaresipCallKitAdapter(engine: engine, configuration: BaresipCallKitConfiguration(supportsVideo: true))
let uuid = try await callKit.startOutgoingCall(to: "sip:door@192.0.2.10", video: true)
```

Incoming early media (preview before answering, for example at a door intercom): `sendProgress(callID:earlyVideo:)` answers the INVITE with 183 Session Progress and receives the caller's audio, and video when `earlyVideo` is true, while the call is still ringing. During the preview the local direction is receive-only, so the caller does not hear or see you; answering switches both directions back to send and receive. `answerEarlyMedia: true` on the account does the same automatically for incoming calls, except while another call is active (a waiting call is not previewed over the current conversation). If answering fails, the preview directions are restored, so nothing is sent before the call is really answered. CallKit activates the audio session only after the user answers, so to hear the caller during a preview the app activates the session itself (`BaresipAudioSessionController.activate()`), as the sample app does; video preview needs no audio session. The `.incomingCall` event tells whether the caller offered early video. The call state is `earlyMedia` until you answer or reject.

Incoming calls are reported to CallKit when the INVITE arrives. After a VoIP push, report the call first with `reportIncomingCallFromPush(uuid:remoteURI:displayName:hasVideo:completion:)`, which hands the call to CallKit before it returns, as iOS expects inside the PushKit delegate method (an `async` variant without the completion handler exists for other code). When CallKit refuses the call, for example during Do Not Disturb, the pushed call is forgotten. Otherwise, when the INVITE arrives it is bound to the oldest pushed call it matches: a push with the caller's user and host matches that user and host, a push with only a user matches that user on any host, and a push without a caller matches the next INVITE unless `matchesPushWithoutCaller` is `false` (such a pushed call then ends after the timeout). A match on user and host wins over weaker ones. CallKit is then updated with the INVITE's own URI and display name, and if the user already answered, the call is answered immediately, with the camera only when the push announced video. If no INVITE arrives within `pushInviteTimeout` (30 s by default) the CallKit call is ended. A pushed call the user declines before its INVITE arrives is remembered for the same time, and the INVITE is then rejected with 486 instead of ringing again. A push for a call whose INVITE already rings is reported and ended at once as answered elsewhere, because iOS requires a report for every VoIP push; the ringing call keeps its own UUID. The `From` header of an INVITE is not authenticated, so the match shows who the INVITE claims to be from; put the caller's full SIP URI in the push and let only your SIP server reach the device. Answering from the CallKit UI sends the camera when the call offers video, unless `sendsCameraOnAnswer` is `false`; the caller's video is received either way. Hold, mute, DTMF and end actions are forwarded to the engine; `setMuted(_:uuid:)`, `setOnHold(_:uuid:)` and `answerCall(uuid:)` go through CallKit so an app's own screens and the system screen stay in step, and `setMuteHandler(_:)` reports mute changes made on the system screen. Outgoing progress is reported from `outgoingRinging`/`earlyMedia` (connecting) and `connected` (connected).

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

`blindTransfer(callID:to:)` sends a REFER without consulting the target. For an attended transfer put the first call on hold, call the target, talk to it, then call `attendedTransfer(callID: firstCall, replacing: consultationCall)`: the first party receives a REFER with `Replaces` and calls the target, the target's call is replaced without ringing, and both of your calls end. When the other side transfers you, the SDK follows the REFER automatically (a new outgoing call appears as `.call(newID, .outgoingInit)` and the old call ends when the transfer succeeds); set `acceptTransfers: false` on the account to decline transfers with 603. The new call's `BaresipCallInfo.replacesCallID` names the old call, which ends with `BaresipCallEndReason.replaced`, and an INVITE with `Replaces` that takes over an established call is marked the same way; the CallKit, LiveCommunicationKit and Telecom adapters move the system call to the new call instead of ending it.

## PushKit

```swift
let push = BaresipPushKitAdapter(engine: engine, appID: "com.example.myapp", accountID: id) { payload in
    callKit.reportIncomingCallFromPush(uuid: nil, remoteURI: payload["from"] as? String, displayName: nil, hasVideo: false) { _ in }
}
push.updateRemoteToken(apnsToken)
```

The adapter only transports token information into SIP; it never sends pushes. iOS requires every VoIP push to be reported to CallKit before the PushKit delegate method returns. The handler therefore runs inside that method, on the main queue, and is not `async`: report the call before returning, without a `Task`, and throw when you cannot. The adapter then reports and immediately ends a placeholder call, still inside the delegate method, on a provider of its own that keeps the call out of Recents and is invalidated afterwards. Create the adapter early in `application(_:didFinishLaunchingWithOptions:)`, because a push that launches the app is delivered as soon as a push registry exists.

Token, `app-id` and account changes are sent to the engine one after the other, and an update overtaken by a newer one is skipped, so the registrar ends up with the latest state. The adapter owns the bound account's Contact parameters: each update replaces all of them, including `BaresipAccountConfiguration.contactParameters`, so pass any other parameters the account needs as `additionalContactParameters` (or later with `updateAdditionalContactParameters(_:)`) and they are sent together with the push ones. Errors of this background work reach `setErrorHandler(_:)` with the step that failed: `contactParameters`, `incomingPush` (the handler threw and a placeholder was reported) or `engineWakeUp`.

After the handler returned, the adapter calls `prepareForPushWakeUp()`. A running engine sends a REGISTER for every account that registers. An idle, stopped or failed engine is started and has no accounts, because stopping removes them, so add the account and register again as after a normal start; the pushed call waits `pushInviteTimeout` for its INVITE.

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

H.264 (`packetization-mode=1`, baseline `42e01f`) is encoded and decoded by VideoToolbox; VP8 is available with `MODULE_SET=full`. Frames reach renderers as `CVPixelBuffer`s: camera frames on the capture queue, remote frames on the engine thread, where baresip decodes them. A renderer must return quickly; `BaresipVideoView` does. Frames from the hardware decoder and straight from the camera wrap the original buffer, without a copy (retain one if you keep it past the callback); VP8, other software frames, and a camera frame the engine converted for the encoder (for example the local preview while the camera is sent in a call) have no native buffer and are copied into an IOSurface-backed buffer, with I420 copied as NV12 so `AVSampleBufferDisplayLayer` can show it. RTCP NACK, PLI and FIR are handled by baresip.

## TLS

Verification is on by default with TLS 1.2 as the minimum. Without further settings the server is verified against the system trust store (SecTrust), so a server with a public certificate works as is. Provide a private CA in memory with `tls.caCertificatesPEM`, which may hold several certificates; a chain it does not anchor is still checked against the system store. Pin SPKI SHA-256 hashes (base64, the same format as HPKP) with `tls.pinnedSPKISHA256`; a connection is accepted only when the chain verifies and at least one certificate matches a pin. The same settings apply to SIP over TLS, WSS and TURN over TLS. Verification cannot be turned off: for a test server with a self-signed certificate, put that certificate (or its CA) in `tls.caCertificatesPEM`. The account's `transport` is enforced: a registrar or outbound proxy without a `transport` parameter gets the account's, and one that names another transport is rejected.

Media is encrypted with SRTP when `mediaEncryption` asks for it. The default, `.srtpOptional`, is best effort: with a peer that does not support SRTP the call goes on with unencrypted media, which `callStatistics` shows; `.srtpMandatory` offers SRTP only. Both SRTP modes send the media keys inside the SIP message (SDES), so they protect the media only when the account uses `.tls` or `.wss`; with `.udp` or `.tcp` the core logs a warning. [C-ABI.md](C-ABI.md#media-encryption) describes the defaults and the risks.

Compute a pin:

```bash
openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
```

## ICE, STUN, TURN

`nat.mode` selects `.none` (symmetric RTP/latching, for deployments with a server-side media relay), `.stun` or `.ice`. `BaresipConfiguration.iceRelayOnly` restricts ICE to relayed candidates for every call (useful to hide the device address or to force a known media path); it is an engine-wide setting because baresip applies the ICE policy globally. TURN works inside ICE over UDP (`turn:host:3478`), TCP (`turn:host:3478?transport=tcp`) and TLS (`turns:host:5349`, verified against the CA configured in `tls`, and subject to the same pins). With TCP or TLS the call uses relayed candidates only, which is what networks that block UDP need. `.ice(...)` events report gathering, checking, connected (with local and remote candidate types and addresses) and failed; `callStatistics` carries the same selected pair.

Video bitrate adapts to packet loss by default (`BaresipConfiguration.videoAdaptiveBitrate`): every second the SDK reads the RTCP receiver reports for the video stream, lowers the encoder target when more than 10 % of the packets were lost and raises it slowly while loss stays under 2 %, between `videoMinimumBitrate` and `video.bitrate`. `setVideoMaxBitrate(_:callID:)` caps one call (for example on a cellular link or when the app goes to Picture in Picture); `nil` removes the cap. `callStatistics(callID:)` reports the current target as `videoTargetBitrate`.

ICE restarts on network changes: when `networkDidChange(updateCalls: true)` finds that a call's local address changed, ICE calls restart ICE with new credentials and freshly gathered candidates and re-INVITE once gathering is done (calls without ICE get the plain re-INVITE with the new address). `restartICE(callID:)` restarts ICE for one call on demand; without a network change it keeps the gathered candidates and TURN allocations and only renews the credentials. A peer's ICE restart is answered with new credentials. Media pauses while the new candidates are checked. Asterisk (checked with 23.5) only restarts its ICE session when the candidates change as well, so `restartICE(callID:)` without a network change fails against Asterisk; restarts caused by an address change work.

## Privacy manifest

`BaresipKit` ships a privacy manifest (`Sources/BaresipKit/Resources/PrivacyInfo.xcprivacy`) that Xcode merges into the app's privacy report. It declares no tracking and no collected data, and one required-reason API category: file timestamps (`stat` and `fstat`, used by libre, baresip's uuid module and OpenSSL for files inside the app container), with reason `C617.1`. The SDK uses no boot time, disk space, keyboard or user defaults APIs.

Calls carry the user's voice, video and phone numbers to the SIP server the app configures. Whether that counts as collected data depends on the app and its server, so the app declares it in its own manifest and App Store privacy details, together with its own API use. The sample app's manifest (`Examples/SampleApp/SampleApp/App/PrivacyInfo.xcprivacy`) adds `UserDefaults` with reason `CA92.1`.

## Logging

`setLogHandler` receives every core, SIP and media line with level and domain; `logSIPTrace` adds the full SIP messages. Digest responses, `pn-tok` values (after an 8-character prefix), passwords and STUN passwords are redacted before the handler is called.
