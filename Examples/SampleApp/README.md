# Sample app

A SwiftUI app built on the SDK, laid out like the system Phone and Settings apps:

- **Calls**: account status, a dial card (audio, video, message), the list of calls (direction, peer, duration, codec; switch, hold or resume, hang up from the context menu) and the latest message.
- **In call** (full screen): caller, duration, encryption, codec and ICE path, live loss, jitter, RTT and MOS, then mute, keypad, speaker, hold, video and transfer, switch camera and restart ICE when they apply, and hang up; the chevron returns to the call list while the call goes on.
- **Incoming call**: Preview hears (and sees) the caller before answering without sending your audio or video, then Answer or Decline; an automatic preview can be turned on in Account.
- **Transfer**: consult first (the call goes on hold, the target is called) and complete the attended transfer, end the consultation, or transfer blind.
- **Messages**: conversations and a thread view with delivery status for SIP messages.
- **Account**: domain, transport, port, outbound proxy, credentials (Keychain), server CA (PEM or DER), client certificate, SPKI pins, media encryption, ICE with STUN/TURN; certificates are kept in protected app storage.

It also shows the audio session helper, the CallKit adapter, the PushKit adapter and network change handling.

Generate the Xcode project with [xcodegen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
cd Examples/SampleApp
xcodegen generate
open BaresipKitSample.xcodeproj
```

The project references the package at the repository root, so `Build/out/BaresipKitCore.xcframework` must exist (run `Build/build-xcframework.sh` first). Set your own bundle identifier and team for CallKit and PushKit; VoIP pushes also need the Push Notifications capability and a VoIP certificate on the server side.

The XCFramework ships an arm64 simulator slice only, so the project excludes x86_64 for simulator builds. Build `SLICES="ios-arm64 ios-arm64-simulator ios-x86_64-simulator"` if you need Intel simulators.

## UI test

`UITests/RegistrationCallUITests.swift` drives the app on a simulator: it enters the domain, port, username and password, registers over TLS against a server whose self-signed certificate is the app's CA, checks that a wrong SPKI pin makes registration fail and that clearing it registers again, then places an audio call to a peer and hangs up. CI runs it on macOS against `Tools/ContactParameterProof/tls_registrar.py` and the `bsk_test_call peer` binary on the runner. To run it yourself, start both on your Mac and pass `TEST_RUNNER_BSK_UITEST_HOST=<mac ip>` and `TEST_RUNNER_BSK_UITEST_CA_PEM="$(cat cert.pem)"` to `xcodebuild test`. With `BSK_UITEST=1` in its launch environment the app starts with empty settings, takes the CA from `BSK_UITEST_CA_PEM`, uses generated audio instead of the microphone and places calls without CallKit.
