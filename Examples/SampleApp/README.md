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
