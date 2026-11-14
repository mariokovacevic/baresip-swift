# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Beta, not released yet. The SDK is in active development, and the API can still change.

### Added

- SIP registration over UDP, TCP and TLS, with private CAs, mutual TLS and SPKI pinning, and
  push `Contact` parameters (RFC 8599 style) updated in place, without leaking the previous value
  and with clearing supported (patch 0015); an update waits for the response to a REGISTER that
  is still unanswered instead of sending a second one (patch 0001), and a REGISTER that libre
  starts itself replaces a pending one instead of overlapping it (patch 0019); a request that
  is replaced or released before any response is freed at once instead of staying allocated
  until the engine stops (patch 0020). Registering again during an unanswered REGISTER, for
  example after a network change, no longer lets the replaced registration client remove the
  binding of the new one afterwards (patch 0021). A TCP or TLS connection whose `recv()` fails,
  such as one iOS dropped while the app was suspended, is closed at once instead of being polled
  again in a busy loop that flooded the log when the app came back (patch 0022). TLS to a server
  given as an IP address requires a certificate whose IP address SAN matches (libre 4.12.0).
- Audio calls with Opus, G.722 and G.711, offered in that order by default. G.722 is built into
  the core from the BSD-licensed sippy/libg722 sources; its license is in
  `THIRD_PARTY_NOTICES.md`. The engine's codec lists apply to every account without its own.
- H.264 video calls through VideoToolbox with zero-copy decoded frames, recovering after the app
  returns from the background; VP8 in the `full` module set. Snapshots with
  `BaresipVideoFrame.makeImage()` and `BaresipVideoView.snapshot()`.
- SIP session timers (RFC 4028), on by default with `BaresipConfiguration.sessionTimer` (30
  minutes) and `minimumSessionTimer` (90 seconds): offered in every INVITE, accepted from callers
  that support them, refreshed with UPDATE (or a re-INVITE without an offer) at half the
  interval, and a call that is not refreshed is ended with BYE. A 422 raises the interval to the
  peer's `Min-SE`, an interval below `minimumSessionTimer` is answered with 422, an INVITE with
  `Require: timer` is accepted, and a refresher that cannot send its refresh ends the call itself
  when the interval runs out. libre and baresip have none; patches 0024 and 0025 add them. C ABI 0.10:
  `bsk_engine_config.session_expires` and `session_min_se`; capability `call.session-timer`.
- Calls answered or declined on another phone: when several phones ring for one call and one
  answers, the server cancels the others with `Reason: SIP;cause=200` (RFC 3326). The ended
  event's `BaresipError.endReason` then says `answeredElsewhere` (or `declinedElsewhere` for
  cause 600 or 603), with the cause and text in `sipStatus` and `sipReason`, and the CallKit and
  LiveCommunicationKit adapters report the call as answered or declined elsewhere instead of
  missed. C ABI 0.11: `bsk_event.u.call_state.end_reason`. The sample lists such calls as
  "Answered on another phone" and leaves no missed ring notification.
- Calls that go on in another call keep their system call: when the server replaces an
  established call with an INVITE carrying `Replaces` (RFC 3891), as call pickup, queues, parking
  and attended transfers do, or when the other side transfers a call with REFER (RFC 3515) and
  the engine follows it, the new call's `BaresipCallInfo.replacesCallID` names the old call and
  the old call ends with `BaresipCallEndReason.replaced`. The CallKit, LiveCommunicationKit and
  Telecom adapters move the system call to the new call instead of ending it and ringing again,
  so the call screen, the audio session and Bluetooth stay as they were; if no call replaces it
  within five seconds the system call ends. C ABI 0.12: `bsk_call_info.replaces` and
  `BSK_END_REPLACED`.
- Hold, resume, mute (`BaresipCallInfo.isMicrophoneMuted`), DTMF over RFC 4733 and SIP INFO,
  several calls with switching, blind and attended transfer (REFER with Replaces), and following
  incoming transfers.
- Music on hold from the phone, from a WAV file: with
  `BaresipAudioConfiguration.holdMusicFile` (a 16-bit PCM WAV file) a held call plays it to the
  other side in a loop instead of the microphone, also while iOS has deactivated the audio
  session, and also when baresip renews the audio source during the hold. baresip drops every
  RTP packet of a held stream; patch 0023 lets the core send the music. Without the file a held
  call sends nothing, as before. The file is read with libre's WAV reader and resampled with its
  filtered resampler when its rate is a whole multiple or fraction of the call's (linear
  interpolation otherwise, for example 44.1 kHz); muting a held call keeps the music playing. A
  file that is missing fails with `notFound`, one in another format with `unsupported`, one that
  is too short or too long with `invalidArgument`. C ABI 0.9: `bsk_engine_config.hold_music_path`.
- `BaresipCallKitAdapter.setRingtoneSound(_:)` changes the ringtone of the running CallKit
  provider, for a ringtone the user picks in the app's settings.
- Door stations and intercoms: every call negotiates video, so the other side's picture is shown
  in audio calls too, and `video` only decides whether the camera is sent; calls without audio
  (`makeCall(…audio:)`, `answer(callID:video:audio:)`); a video-only early media preview
  (`sendProgress(callID:earlyVideo:earlyAudio:)`); headers of incoming INVITEs
  (`incomingHeaders`, `incomingHeader(_:callID:)`); picture update requests over SIP INFO
  (`pictureUpdateOverSIPInfo`, patch 0012).
- SIP MESSAGE (RFC 3428), early media preview of incoming calls, call recording to stereo WAV,
  and media statistics with a MOS estimate.
- SRTP (SDES) and DTLS-SRTP, with SDES keys redacted in logs; ICE with STUN and TURN over UDP,
  TCP and TLS (patch 0007), ICE restart on network changes; a TURN server over TCP or TLS that
  refuses the connection, fails TLS, rejects the allocation or does not answer within 10 seconds
  ends the call attempt with an error, a relay connection lost during a call is reported as ICE
  `failed` and `restartICE` connects again, and an ICE restart that fails keeps the call and
  reports `failed` (patch 0008); RTCP multiplexing (RFC 5761); a NAT
  pinhole for receive-only streams (`BaresipNATConfiguration.pinhole`, patch 0011); adaptive
  video bitrate from RTCP loss.
- `BaresipKitAudio` with audio output selection (`availableOutputs`, `selectOutput(_:)`), and
  audio that starts only once the audio session is active; `BaresipKitVideo`;
  `BaresipKitCallKit` with answer, mute and hold through CallKit and `sendsCameraOnAnswer`;
  `BaresipKitPushKit` with `updateAppID(_:)`; `BaresipKitSwiftUI` with `BaresipPhone` and
  `BaresipPhoneCall`, observable registration and call state for SwiftUI.
- Calls announced by a VoIP push are bound to their INVITE in arrival order by the caller's user
  and host. CallKit then shows the INVITE's own caller, an answer given before the INVITE sends
  the camera only when the push announced video, and
  `BaresipCallKitConfiguration.matchesPushWithoutCaller` turns off binding pushes that name no
  caller. `reportIncomingCallFromPush(uuid:remoteURI:displayName:hasVideo:completion:)` reports
  without suspending, for use inside the PushKit delegate method, and a pushed call that CallKit
  refuses leaves nothing behind. A pushed call declined before its INVITE arrives rejects that
  INVITE with 486, and a push for a call that already rings does not ring a second time.
- `BaresipCallKitAdapter` binds a pushed call to its INVITE by a UUID from the server instead
  of by the caller when `BaresipCallKitConfiguration.callUUIDHeader` names the INVITE header
  that carries it: the UUID from the push payload identifies the call, an INVITE that arrives
  first keeps the UUID from its header, and a push repeated for a call CallKit already shows is
  reported under a new UUID and ended at once. `reportIncomingCallFromPush(uuid:…)` takes `nil`
  when the payload has no UUID; such a push is matched by its caller, also with an INVITE that
  carries a UUID, instead of ringing as a second call. A start action that CallKit times out
  while the engine is placing the call no longer leaves the call running without a CallKit
  call. `includesCallsInRecents` controls the Recents
  list of the Phone app, and `BaresipRedialRequest` reads the request to call again that a tap
  there sends to the app. `handleStyle` reports callers with a numeric user as phone numbers,
  so iOS shows the matching contact. An action CallKit times out fails its caller with
  `BaresipCallKitError.actionTimedOut`, and the call whose start or answer timed out is ended
  on the engine too.
- `BaresipPhone.call(withPeer:)` finds the established call with the sender of a SIP MESSAGE,
  and `BaresipPhoneCall.isPeer(_:)` and `samePeer(_:_:)` compare SIP addresses by user and host,
  ignoring display names, ports and parameters. The sample shows a message from the call's
  other side as a caption over the call's video and opens the conversation over the call with
  a chat button that counts the unread messages.
- LiveCommunicationKit, CallKit's successor, from iOS 17.4: `BaresipLiveCommunicationAdapter`
  in the new `BaresipKitLiveCommunication` product reports calls as conversations, carries out
  join, end, pause, mute and keypad tones on the engine, and matches pushes to INVITEs like the
  CallKit adapter. `BaresipPushKitAdapter.reportingAsynchronously` takes an `async` push handler
  and completes the push after it returned, because LiveCommunicationKit reports calls only
  asynchronously. `BaresipRedialRequest` and the handle style (now `BaresipHandleStyle`) moved
  to `BaresipKit` so both adapters use them. The sample app chooses between CallKit and
  LiveCommunicationKit under Settings, Call screen.
- `BaresipPushKitAdapter` calls its handler inside the PushKit delegate method, so the call is
  reported to CallKit before that method returns; when the handler throws, a placeholder call is
  reported and ended in place. Token updates are sent in order and coalesced,
  `additionalContactParameters` are sent together with the push parameters, and
  `setErrorHandler(_:)` reports failed updates, pushes and wake-ups.
- `BaresipAudioSessionController` resumes after an interruption only when iOS reports
  `shouldResume`, activating the session again first when it had activated it, and restores the
  VoIP category and restarts audio after a reset of the media services.
- `BaresipPhone.run()` refreshes the calls it already tracks from the engine, so a call answered
  while no view ran no longer reads as incoming, and `BaresipCallKitAdapter` follows the
  engine's events from the moment its initializer returns.
- What every app needed to write itself is now in the SDK, each part optional:
  - `BaresipCallController`, which `BaresipCallKitAdapter` implements: give it to `BaresipPhone`
    and its calls answer, decline, end, hold, mute and place calls through CallKit for the calls
    CallKit shows, and through the engine otherwise. Muting on the system call screen updates
    the call. `answerCall`, `endCall`, `setHeld` and `setMuted` of the adapter return once the action
    was carried out on the engine and throw its error when it failed there.
  - `BaresipPhone.activeCall` and `makeActive(_:)`: the call placed or answered last, also on the
    system call screen, is active; when it ends, a held call becomes active and is resumed
    (`resumesHeldCallWhenActiveCallEnds`).
  - `BaresipPhoneCall` with `isSendingVideo`, `isReceivingVideo`, `setVideoEnabled(_:)`,
    `camera`, `setCamera(_:)`, `switchCamera()`, `connectedAt`, `startPreview(video:audio:)`,
    `receivedDTMF`, `displayName`, and `sendDTMF(_:expectingReply:timeout:)` for door codes the
    station confirms with a digit.
  - `BaresipCallVideo`, a SwiftUI view of a call's remote video or camera image that attaches and
    detaches itself, and `BaresipSelfView`, the picture of your own camera in a corner while it is
    sent, mirrored for the front camera, switching cameras on a tap.
  - `BaresipAppLifecycle`: in the background with no call it unregisters every account
    (`backgroundBehavior = .goOffline`) or suspends the engine and keeps the registrations for
    VoIP push (`.suspend`, the default); when the app is active again it opens the transports and
    registers again; when the app terminates it stops the engine, unregistering every account.
    The sample app goes offline in the background.
  - `BaresipNetworkMonitor` calls `networkDidChange` when the available interfaces change.
  - `BaresipCertificates` checks a CA bundle (PEM or DER) and a client certificate with its
    unencrypted key before use, with errors to show the user.
  - `BaresipFileLog` writes the log to one file per day, also while the device is locked.
  - `BaresipCameraPosition` and `BaresipEngine.setCamera(_:callID:)` with it.
  - Frames without a native buffer, such as the camera image the engine converted for the
    encoder, are copied into an IOSurface-backed buffer and I420 as NV12, so `BaresipVideoView`
    shows your own camera instead of a black picture.

  The sample app uses all of them instead of its own versions.
- TLS servers are verified against the system trust store when no CA is configured or the
  configured CAs do not anchor the chain (SecTrust on Apple platforms, patch 0018); a CA bundle
  may hold several certificates. `verifyServer` is read-only and verification can be turned off
  only with `insecureSkippingServerVerification()` in DEBUG builds, never together with pins.
  Pins must be base64 SHA-256 values. The WSS transport uses the same CA, client certificate and
  pins (patch 0017). The account's transport is enforced on the registrar and outbound proxy.
- A REFER is followed only on an established call (patch 0016), and an INVITE replaces a call
  only when its own `Replaces` header names that call. Rejecting works on ringing calls only; a
  cancelled outgoing call ends as ended, not failed.
- Requests made from event or log handlers are safe: hanging up and removing an account wait
  until the handler has returned. Removing an account or stopping the engine ends its calls
  first. Replacing a video renderer waits for a frame that is still being rendered.
- A hold or resume requested while an earlier change is being negotiated is sent when that
  change is done instead of being lost; a direction change reports `.busy` then. A change the
  other side rejects returns the call to its previous state with an error.
- `BaresipEngine.accounts()` lists the accounts with their registration state, and
  `BaresipPhone.registrations` starts from it. An unregistered account ends in the `none` state
  and stays unregistered across network changes and push wake-ups. One engine may run per
  process; a second `start()` fails with `.busy`.
- `networkDidChange()` reads the local addresses again, so an engine started without a network
  comes up when one appears.
- Input that would reach a SIP message or the baresip configuration is rejected when it contains
  control characters; at most one TURN server is accepted. The log also masks DTMF digits, ICE
  passwords, passwords in SIP URIs and the bodies of MESSAGE requests.
- Recording keeps going when the audio sample rate changes, and reports a file that cannot be
  written (`BaresipEvent.audio`) or stayed empty (`stopRecording` throws `.media`).
- The audio packet time (`packetTime`) and the RTP timeout (`rtpTimeout`) take effect. Settings
  that had no effect are gone: `registerRetry`, `keepAlive`, `symmetricRTPLatching`,
  `voiceProcessing` and `hardwareAcceleration`.
- A privacy manifest for the SDK: no tracking, no collected data, and file timestamp APIs
  (`stat`, `fstat`) with reason `C617.1`; the sample app has its own.
- macOS 13 or later on Apple silicon (beta): a `macos-arm64` slice in the XCFramework, and
  `BaresipKit`, `BaresipKitVideo` and `BaresipKitSwiftUI` on macOS; the iOS-only adapters compile to
  nothing there. CI builds the package for macOS and runs the unit tests on it.
- `Scripts/dev-pbx.sh`: the integration tests' Asterisk and coturn as a local server for manual
  testing on a phone, with a random TURN password and without relaying to the computer's
  loopback interface.
- The sample app has a prototype of a preview for a call that rings while the app is in the
  background: a notification with the caller's picture, Answer, Decline and Open door, and a
  notification content extension that follows the picture while the call rings. It has not been
  tried on a device yet; see the sample's README.
- `Tools/DoorStack`: a PBX, a push gateway and a door station simulator in Docker, for trying the
  sample app as a video intercom. A ring wakes a suspended phone with a VoIP push and reaches it
  once it has registered again; a scripted phone checks the whole path without Apple's servers.
- The sample app looks like a video intercom, Zvono: a dark design with brass for ringing and
  opening, a bell with a keyhole as its icon and logo, Barlow Semi Condensed for titles, and the
  tabs Doors, Activity, Keypad, Messages and Settings. Saved doors carry their own SIP user,
  code, camera and opening options; Open calls the door, sends the code and hangs up, and the
  ringing, in-call and notification screens offer Open door for a saved door. The door code in
  Account is gone, the ring notification's picture can be turned off, and the registration time
  goes up to a week. The call screen moves transfer, recording, sound output and call quality to
  More; the engine state and the log are in Settings, Diagnostics.
- A SwiftUI sample app with call history, DTMF codes, a file log and local profiles, and a UI
  test that runs in CI. SIP messages are logged only when turned on in the Log screen (off in
  release builds), stored certificates can be read after the first unlock and are deleted only
  when removed, and the UI test hooks exist only in debug builds.
  Its Account screen exposes the account and engine settings for testing: NAT traversal (none,
  STUN, ICE with TURN and relay only), rtcp-mux, the NAT pinhole, the RTP timeout, IPv6, SIP
  Outbound, the registration time, the DTMF method, accepting transfers, codec order, and video
  size, frame rate, bitrate and adaptive bitrate. Saved settings from earlier versions are kept.
- DocC documentation for every public symbol, with Getting Started, Audio Session, Video,
  CallKit, PushKit and Push Contact Parameters articles.
- Built on baresip and libre 4.13.0, with the patches in `Patches/` rebased onto it, and patch
  0026 for a 4.13.0 regression that kept music on hold from replacing the microphone.
- iOS 16 or later, Swift 6 language mode with strict concurrency; Swift and C sources build
  without warnings. C ABI 0.9.
- Lint and format scripts, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, and issue and pull request
  templates.
- CI builds libre and baresip with ASan and UBSan on Linux for the core tests, the fuzzer and
  the integration suite, which also checks that a call with an unusable TURN server fails within
  a bounded time. GitHub Actions are pinned by commit and the Asterisk image by digest.
- The H.264 RTP depacketizer (single NAL, FU-A, STAP-A) and the Annex B to AVCC conversion are
  platform-independent code in `Core/src/bsk_h264.c`, covered by unit tests and the fuzzer on
  Linux; the VideoToolbox decoder uses them.
- A release workflow that requires a green CI run, uploads the assets to a draft release before
  it pushes the commit and the tag in one atomic push, and can be run again after a failure.
- OpenSSL is built with `no-autoload-config` and without the build path in the library.

### Changed

- `BaresipCallKitAdapter` and `BaresipLiveCommunicationAdapter` have `setAudioSessionHandler(_:)`,
  which sends the system's audio session activation to a handler, such as a
  `BaresipAudioSessionController`, instead of to the engine. Until now the controller could not
  learn that CallKit owned the session while an adapter was in use, so after an interruption it
  resumed the engine without waiting for CallKit, and its CallKit path was unreachable.

- `Docs/STABILITY.md` states what Semantic Versioning covers from 1.0 on: the public Swift and
  Kotlin API, documented behaviour and the minimum OS versions. The C ABI, internal modules, log
  formats and the samples are not covered. Enumerations and sealed types can gain cases in a minor
  release, so `switch` and `when` over them need a `default` / `else` branch.
- `Docs/C-ABI.md` is no longer a proposal: it states that the C ABI is shipped in lockstep with the
  SDKs, that output structs grow at their end, that bindings ignore unknown values, and corrects
  what it said about wiping passwords, re-entrant events, `bsk_engine_destroy` and
  `BSK_EVENT_DIAGNOSTIC`.
- Swift API, before the 1.0 freeze (BREAKING):
  - `BaresipEngine.hangup(callID:)` is `hangUp(callID:)`, and the system call adapters'
    `setHeld(_:uuid:)` is `setOnHold(_:uuid:)`.
  - `BaresipCallInfo.account` is `accountID`.
  - `BaresipConfiguration.init` takes `instanceUUID` as its first, required parameter. A random
    default gave every launch a new `+sip.instance`, which left stale bindings on the registrar
    that incoming calls were forked to; store the UUID once per installation and pass it every
    time.
  - `BaresipCallKitAdapter`, `BaresipLiveCommunicationAdapter` and `BaresipPushKitAdapter` no
    longer conform to `CXProviderDelegate`, `ConversationManagerDelegate` and
    `PKPushRegistryDelegate` themselves, and the first and last are no longer `NSObject`
    subclasses. The system callbacks go to private objects, so an app can no longer call them or
    replace the adapter as the delegate by mistake.
  - Plumbing is internal: `BaresipEngine.isEngineThread`, `abiVersion` and `capabilities`,
    `BaresipNetworkEvent.init`, and `BaresipPhoneCall.refresh()`, `userPart(of:)` and
    `samePeer`.
  - `BaresipCallController` is documented as implemented by the SDK's adapters only.
- The version comes from the `VERSION` file: the core reports it in `bsk_version_string()` and in
  the default `User-Agent` (`BaresipKit/<version>` instead of `BaresipKit/beta`).
- Releases: `Package.swift` uses a local `Build/out` XCFramework only on the default branch, where
  no release URL is set, or with `BARESIPKIT_LOCAL_CORE=1`; a stale local build no longer
  replaces the published binary at a release tag. The release workflow defaults to a dry run,
  checks `VERSION` and `CHANGELOG.md`, publishes the XCFramework that CI built and tested instead
  of a new build, adds an SPDX SBOM, `SHA256SUMS` and provenance attestations, and tags a release
  commit without pushing it to the default branch.
- `THIRD_PARTY_NOTICES.md` has the upstream copyright lines of libre and baresip, the Android
  sample's fonts, and no longer says that OpenSSL's NOTICE must ship (OpenSSL 3 has none). The
  license texts of the pinned sources are in `LICENSES/`, checked against the sources in CI.
- `Docs/STABILITY.md` also states that creating output types yourself (initializers, Kotlin
  constructors, `copy` and `componentN`) and implementing SDK protocols are not covered.

### Fixed

- PushKit: an asynchronous push handler (`reportingAsynchronously`) that never returned kept the
  push open until iOS ended the app. It now has a deadline, `reportDeadline` (5 seconds by
  default): the handler is cancelled, a placeholder call is reported and ended, and the error
  handler gets `BaresipPushKitError.reportTimedOut`.
- CallKit and LiveCommunicationKit: a request the system accepted but never carried out kept
  `placeCall(to:video:)` and the action methods waiting forever; they now fail with
  `actionTimedOut` after a minute. A reset of the provider or conversation manager fails pending
  requests with the new `BaresipCallKitError.providerReset` or
  `BaresipLiveCommunicationError.managerReset` instead of `CancellationError`.
- iOS video: the front camera was mirrored at capture, so the other side saw a mirrored picture
  and the self view, mirrored again by `mirrored: true`, was not mirrored. The camera is no
  longer mirrored at capture. On iOS 16, `BaresipVideoView` flushes a failed display layer, so
  video recovers after the app returns from the background, and shows only the newest frame
  when the main thread falls behind, instead of starting a task for every frame.
- Android: a pushed call answered as audio-only from the system UI before its INVITE arrived no
  longer sends the camera.
- Android: an exception while the Telecom adapter handles one event, for example a call Telecom
  never added, no longer stops it from handling every later call, and no wait for Telecom blocks
  the events behind it longer than `actionTimeout`.
- Android: `BaresipCallVideo` and `BaresipCameraPreview` attach and detach in one coroutine, so
  leaving the screen quickly no longer leaves the camera running, and a composable that leaves
  no longer stops the preview or renderer of the one that replaced it.

### Security

- SPKI pins are checked against the certificate chain the system trust store validated, not
  against every certificate the server sent. Before, a server with any chain the system trusts
  for the host could append the pinned certificate and pass the pin check. Pins with a private
  CA (`caCertificatesPEM`) were already checked against the verified chain.
- Server certificate verification can no longer be turned off. `insecureSkippingServerVerification()`
  is gone from the Swift API (where it existed in DEBUG builds, so every Debug build of an app had
  it) and from the Kotlin API (where it existed in every build), with `verifyServer` on both. The C
  field `insecure_skip_verify` is rejected unless the core is built with
  `BARESIPKIT_ALLOW_INSECURE_TLS`, which no released binary is, and `extra_config` may not set the
  TLS keys (`sip_verify_server`, `sip_cafile`, `sip_capath`, `sip_certificate`,
  `sip_verify_client`). A test server with a self-signed certificate goes in `caCertificatesPEM`.
  The sample apps lose their debug-only "verify server" switch.

### Removed

- Media events the core never emitted: `BSK_MEDIA_AUDIO_STOPPED`, `BSK_MEDIA_VIDEO_STARTED`,
  `BSK_MEDIA_VIDEO_STOPPED` and `BSK_MEDIA_RTP_TIMEOUT` in C, and `BaresipMediaEvent.audioStopped`,
  `.videoStarted`, `.videoStopped` and `.rtpTimeout` in Swift. The unused `bsk_video_codec` enum
  is gone too. Code that names them no longer compiles; the remaining values keep their numbers.
  C ABI 0.11.

[Unreleased]: https://github.com/mariokovacevic/baresipkit/commits/main
