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
- Hold, resume, mute (`BaresipCallInfo.isMicrophoneMuted`), DTMF over RFC 4733 and SIP INFO,
  several calls with switching, blind and attended transfer (REFER with Replaces), and following
  incoming transfers. A received DTMF digit reports whether it arrived as SIP INFO
  (`BaresipDTMFEvent.viaSIPInfo`, patch 0023); before, it was always `false`.
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
- Built on baresip and libre 4.12.0, with the patches in `Patches/` rebased onto it.
- iOS 16 or later, Swift 6 language mode with strict concurrency; Swift and C sources build
  without warnings. C ABI 0.8.
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

[Unreleased]: https://github.com/mariokovacevic/baresip-swift/commits/main
