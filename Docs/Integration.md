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

Incoming calls are reported to CallKit when the INVITE arrives. After a VoIP push, report the call first with `reportIncomingCallFromPush(uuid:remoteURI:displayName:hasVideo:)`; when the INVITE arrives it is matched to that UUID and, if the user already answered, answered immediately. Hold, mute, DTMF and end actions are forwarded to the engine. Outgoing progress is reported from `outgoingRinging`/`earlyMedia` (connecting) and `connected` (connected).

## PushKit

```swift
let push = BaresipPushKitAdapter(engine: engine, appID: "com.example.myapp", accountID: id) { payload in
    try? await callKit.reportIncomingCallFromPush(uuid: UUID(), remoteURI: payload["from"] as? String, displayName: nil, hasVideo: false)
}
push.updateRemoteToken(apnsToken)
```

The adapter only transports token information into SIP; it never sends pushes.

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

H.264 (`packetization-mode=1`, baseline `42e01f`) is encoded and decoded by VideoToolbox; VP8 is available with `MODULE_SET=full`. Frames reach renderers on media threads as `CVPixelBuffer`s (NV12 from the decoder, I420 copied from software sources). RTCP NACK, PLI and FIR are handled by baresip.

## TLS

Verification is on by default with TLS 1.2 as the minimum. Provide a private CA in memory with `tls.caCertificatesPEM`; pin SPKI SHA-256 hashes (base64, the same format as HPKP) with `tls.pinnedSPKISHA256`; a connection is accepted only when the chain verifies and at least one certificate matches a pin. `verifyServer = false` exists only behind `BaresipTLSConfiguration.insecureSkippingServerVerification()` in DEBUG builds.

Compute a pin:

```bash
openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
```

## ICE, STUN, TURN

`nat.mode` selects `.none` (symmetric RTP/latching, for deployments with a server-side media relay), `.stun` or `.ice`. `BaresipConfiguration.iceRelayOnly` restricts ICE to relayed candidates for every call (useful to hide the device address or to force a known media path); it is an engine-wide setting because baresip applies the ICE policy globally. TURN works inside ICE over UDP (`turn:host:3478`), TCP (`turn:host:3478?transport=tcp`) and TLS (`turns:host:5349`, verified against the CA configured in `tls`, and subject to the same pins). With TCP or TLS the call uses relayed candidates only, which is what networks that block UDP need. `.ice(...)` events report gathering, checking, connected (with local and remote candidate types and addresses) and failed; `callStatistics` carries the same selected pair.

## Logging

`setLogHandler` receives every core, SIP and media line with level and domain; `logSIPTrace` adds the full SIP messages. Digest responses, `pn-tok` values (after an 8-character prefix), passwords and STUN passwords are redacted before the handler is called.
