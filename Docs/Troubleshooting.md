# Troubleshooting

Real failure modes, grounded in the engine's error codes, call state and log domains
(`BaresipError`, `BaresipCallInfo`, `BaresipICEEvent`, `BaresipLogDomain` in
`Sources/BaresipKit/Diagnostics` and `Sources/BaresipKit/Network`). For the integration itself,
see [Integration.md](Integration.md); for the SDK's own log redaction and format, see its
"Logging" section.

The examples use the Swift names; the Kotlin types on Android have the same names, and the log,
SIP, media and ICE behave the same on both platforms. The sections about the audio session,
PushKit and the background describe iOS; for Android, check the app checklist in
[Android.md](Android.md#app-checklist).

## Reading the log

`setLogHandler` on the engine receives every line with a `BaresipLogDomain` (`core`, `sip` or
`media`) and a level. For most of the issues below:

1. Set `BaresipConfiguration.logLevel = .debug` while reproducing the problem (it takes effect
   from the next `BaresipEngine(configuration:)`, so a running engine with a different level
   needs restarting to pick it up).
2. Set `BaresipConfiguration.logSIPTrace = true` (before `BaresipEngine(configuration:)`) when the
   failure is in registration or call setup, to see the SIP messages themselves (the core redacts
   `Authorization`/`Proxy-Authorization`, `pn-tok` and SDES keys, so traces are safe to collect and
   attach to a bug report).
3. Look at the `media` domain for RTP, RTCP and ICE lines, `sip` for SIP transactions, and `core`
   for engine and configuration problems.
4. `BaresipFileLog` (`BaresipKitSwiftUI`'s sample app uses it) keeps the last several days on
   disk, including while the device is locked, so a problem that happened earlier can still be
   collected.

Every `BaresipEvent` and `BaresipError` that reports a failure carries a `code` from
`BaresipError.Code`; matching on it is more reliable than parsing `message`, which is for humans.

## Registration fails

Check `.registration(_, .failed, _, let error)` from `engine.events`; `error.code` narrows it:

- **`.tls`**: the TLS handshake or certificate verification failed. Common causes: the server's
  certificate is not covered by the system trust store and no private CA was configured
  (`BaresipTLSConfiguration.caCertificatesPEM`); a wrong SPKI pin
  (`BaresipTLSConfiguration.pinnedSPKISHA256`); the server's certificate does not cover the host
  name or IP address used to reach it (libre 4.12.0 requires an IP SAN when the registrar is
  given as an IP address, see `Patches/README.md`); or a client certificate the server requires
  was not provided. The log's `media`/`core` lines around the failure name the TLS error from
  OpenSSL. Verify the pin independently:

  ```bash
  openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
  ```

- **`.authentication`**: the server answered 401 or 407 and rejected the credentials on the
  retry. Check `authUser` versus the SIP user (they are independent fields), the password, and
  whether the server expects SHA-256 Digest (`libre` supports MD5 and SHA-256; nothing to
  configure, but a server-side digest algorithm mismatch shows as a second 401). A SIP trace
  shows the challenge and the retried request.
- **`.network`**: the transport could not reach the server (DNS failure, connection refused, no
  route). Check the registrar's host and port, the chosen `transport`, and whether the device has
  a route at all (see "Background and offline behaviour" below for the suspended/offline case).
- **`.timeout`**: no response arrived. libre retries registration with exponential backoff (30 s
  up to 30 minutes, with jitter); a registration that keeps timing out and retrying, rather than
  failing once, usually means the server is unreachable rather than rejecting the request, which
  would come back as a SIP status quickly.
- A SIP status is attached whenever the server did respond (`error.sipStatus`,
  `error.sipReason`); a status in the 4xx/5xx range with no identifiable cause above means check
  the server's own log for that request.

## One-way or no audio

1. Check `BaresipCallInfo.audioDirection` on both sides. `sendOnly`/`receiveOnly`/`inactive`
   where `sendReceive` is expected points at a direction negotiated in the SDP, not a transport
   problem; look at the offer and answer in the SIP trace for the `a=sendrecv`/`sendonly`/
   `recvonly`/`inactive` line of the `m=audio` section.
2. **No audio session activated.** The core never opens the audio device until
   `audioSessionDidActivate()` is called (directly, or through CallKit's `provider(_:didActivate:)`
   forwarded by `BaresipCallKitAdapter`). A call connected with no audio on either side, and
   nothing wrong in the SDP, usually means the audio session was never activated — check that
   `BaresipAudioSessionController.activate()` was called when not using CallKit, or that the
   CallKit provider actually activated (iOS does not call `didActivate` when the app was not
   allowed to use the microphone, for example).
3. **One-way audio through a relay.** If the call uses no ICE (`nat.mode == .none`) and a
   receive-only stream never receives, the relay (such as rtpengine) may not have learned the
   device's address because it never sent a packet first. Enable `BaresipNATConfiguration.pinhole`
   so the device sends empty RTP packets until the peer's media arrives, or use ICE.
4. **RTP timeout.** A call that starts with audio and then goes silent on both sides may have
   hit `rtpTimeout`: no RTP arrived for that long and the call ends. Check the `media` log for the
   timeout and confirm with the peer or the network that RTP kept flowing (NAT rebinding, a
   firewall timeout, or a TURN allocation that expired without `restartICE`, see ICE below).
5. Microphone permission: `NSMicrophoneUsageDescription` must be in the Info.plist, and the user
   must have granted it; a denied permission shows as the audio session activating with no
   capture, not as a BaresipKit error.

## Black or missing video

1. Check `BaresipCallInfo.videoDirection`. The engine always negotiates video, and the other
   side's video is received even in an audio call, so a direction of `.inactive` or
   `.sendOnly`-only-locally almost always means **the peer offered video `recvonly`** in its SDP:
   the peer is willing to receive your video but is not sending any of its own. This is normal for
   some devices and not a bug; `grep` the SIP trace for the `m=video` line's direction attribute
   to confirm it before assuming a renderer problem. The log also reports `0` decoded frames for
   that stream, because none were ever sent by the peer.
2. If the peer's own log or behaviour shows it is sending video and nothing renders locally,
   check that a renderer was attached with `setVideoRenderer(_:callID:local:)` before the stream
   started, and that it returns quickly (a slow renderer stalls the engine thread, see
   [Architecture.md](Architecture.md)).
3. **The self view or local preview is black.** `BaresipVideoView`/`AVSampleBufferDisplayLayer`
   only displays an `IOSurface`-backed, bi-planar pixel buffer. Frames straight from the camera or
   the hardware decoder already are; a camera frame the engine converted for the encoder is copied
   into such a buffer automatically (see [Integration.md](Integration.md#video)). If a custom
   `BaresipVideoRenderer` shows nothing for the local preview specifically, check it is not
   assuming a planar `CVPixelBuffer` format it never receives.
4. **Picture freezes after the app returns from the background.** iOS invalidates VideoToolbox
   compression and decompression sessions in the background; the next frame opens a new encoder
   session and sends a key frame automatically, and a lost decoder session is reopened at the next
   key frame (`EPROTO` makes baresip ask the peer for one). If the picture stays frozen longer than
   a second or two after foregrounding, request one explicitly with `requestKeyframe(callID:)`
   (or `BaresipAccountConfiguration.pictureUpdateOverSIPInfo` for peers that ignore RTCP).
5. Camera never starts in the simulator: there is no camera; use the `fakevideo` source for
   development, or test on a device (`Docs/DeviceTesting.md`).

## ICE and connectivity failures

Watch `.ice(let event)` on `engine.events` (`BaresipICEEvent`/`BaresipICEState`) and
`callStatistics(callID:)`, which carries the same selected pair.

- **Stuck in `checking`, then `failed`, no TURN configured**: likely a symmetric NAT or a
  network that blocks the candidate pairs tried. Add a TURN server; with `nat.mode == .ice` TURN
  candidates are gathered automatically when a `BaresipTURNServer` is configured.
- **`failed` with TURN over TCP or TLS**: the connection, TLS handshake or allocation did not
  finish within 10 seconds (fixed limit, see `Patches/0007-...`), so the call attempt fails. Check
  the TURN server's reachability on that exact transport and its certificate if `turns:`.
- **Media stops mid-call, ICE state `failed`, call stays up**: the TURN connection was lost
  (network change, server restart, allocation expired). The connection is not retried by itself —
  call `restartICE(callID:)` to connect, allocate and gather again (see
  [Limitations.md](Limitations.md)).
- **`restartICE` against Asterisk does nothing**: Asterisk (checked with 23.5) only restarts its
  own ICE session when the candidate set actually changes. A restart triggered by a genuine
  network address change works; an explicit restart with the same candidates does not move
  Asterisk's side. This is a known limitation, not a bug in the SDK.
- **ICE restart reports `failed` and keeps the call**: either gathering could not start (for
  example the TURN server is unreachable on the new network) or the peer did not answer with new
  ICE credentials within 15 seconds. No re-INVITE is sent in the first case, so the peer keeps the
  old addresses until a restart succeeds; retry `restartICE(callID:)` or hang up. The STUN/TURN
  server address resolved at call start is reused and not re-resolved, so a server that moved to a
  new address on the new network will not be found until the call is re-established.
- **Relay-only forced but nothing connects**: `BaresipConfiguration.iceRelayOnly` is engine-wide;
  confirm the TURN server actually accepts relayed allocations on the transport configured and
  that its credentials are correct — a TURN authentication failure shows in the `media` log as a
  rejected allocation, not as a SIP error.

## Early media preview is silent on a phone

Expected behaviour, not a bug: on a physical iPhone, iOS only starts playing audio for a call
once CallKit answers it (`provider(_:didActivate:)`), even though the SDK itself is receiving the
caller's 183-Session-Progress audio and decoding it. The sample app's own note: "on a phone iOS
plays the audio only once CallKit answers the call; the simulator plays it while ringing" — the
simulator never routes audio through CallKit's activation, so a preview there is audible while
still ringing, which does not reproduce on a device. To make a preview actually audible before
answering, the app must activate the audio session itself
(`BaresipAudioSessionController.activate()`) instead of waiting for CallKit; see the early media
section of [Integration.md](Integration.md#callkit) and the AudioSession DocC article. A
video-only preview needs no audio session and previews correctly either way.

## Push notifications not arriving

1. Confirm the registrar actually has the current token: `BaresipEngine.encodeContactParameters`
   gives the exact `Contact` header text to compare with a packet capture of the REGISTER.
2. `BaresipPushKitAdapter.setErrorHandler(_:)` reports three failure points:
   `contactParameters` (the engine refused the update, often because the account no longer
   exists), `incomingPush` (the app's handler threw and a placeholder call was reported and ended
   instead), and `engineWakeUp` (the engine could not be restarted after the push). Any of these
   firing explains a push that arrived at the device but produced no ringing call.
3. The adapter never sends pushes itself — if nothing reaches `pushRegistry(_:didReceiveIncomingPushWith:...)`
   at all, the problem is upstream: the VoIP push certificate or token-based key on the push
   sender, or the SIP server/proxy not sending a push for a registered device at all. That is
   outside the SDK's log; check the push sender's own delivery log and APNs feedback.
4. A push arrived and a call was reported, but no INVITE followed within
   `BaresipCallKitConfiguration.pushInviteTimeout` (30 s by default): the CallKit call ends on its
   own. Check whether the INVITE actually left the SIP server (its own log, or a SIP trace on a
   test registrar) and whether the `From` user/host matches what the push announced — a mismatch
   means the INVITE is bound to a different (or no) pushed call; see <doc:CallKit> for the
   matching rules.
5. After a launch caused by a push, the engine starts with no accounts (stopping removes them):
   if the app's launch code does not add the account and register again, the pushed call's INVITE
   has nothing to attach to and the CallKit call times out even though the push itself worked.

## Background and offline behaviour

- With `BaresipAppLifecycle.backgroundBehavior = .goOffline` (the sample app's choice), the app is
  genuinely unreachable in the background: no SIP INVITE will arrive because every account
  unregistered. This is expected, not a connectivity bug; use `.suspend` (the default) if the app
  must stay reachable through a VoIP push while backgrounded.
- With `.suspend`, iOS tells a suspended app nothing when it is removed from the app switcher by
  the user; its registration then simply expires on the server rather than unregistering
  cleanly. A registrar showing a binding for an app the user force-quit is this, not a leak.
- A registration that looks "stuck" after a network change: confirm `networkDidChange(...)` (or
  `BaresipNetworkMonitor`) is actually being called — the engine does not poll the network on its
  own; something has to tell it the path changed.
- One engine runs per process. A `BaresipError.Code.busy` from `start()` almost always means a
  previous engine instance was not stopped (for example after a hot-reload in development, or two
  parts of the app both trying to own the engine).

## When none of this matches

Collect, with `logSIPTrace` enabled and the log level at `.debug`, the log around the failure (redacted credentials
and push tokens are safe to share), the `BaresipError.code` and `sipStatus`/`sipReason` if any,
and the SIP server's own log for the same time window, then open an issue or, for a possible
vulnerability, follow [SECURITY.md](../SECURITY.md) instead of a public issue.
