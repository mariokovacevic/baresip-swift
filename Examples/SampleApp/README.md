# Sample app

A minimal SwiftUI app showing account setup and registration (domain, username, password, transport, port, outbound proxy; CA certificates in PEM or DER for a private CA or self-signed server, a client certificate for mutual TLS, SPKI pins; the password is kept in the Keychain and certificates in protected app storage), audio and video calls (remote and local video, front/back camera), hold/resume, mute, speaker, DTMF, optional ICE with a TURN server, ICE restart on demand and on network changes (via `NWPathMonitor` and `networkDidChange()`), live statistics (loss, jitter, RTT, MOS, video target bitrate, selected ICE candidates), the audio session helper, the CallKit adapter and the PushKit adapter.

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
