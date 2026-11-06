# Sample app

A minimal SwiftUI app showing registration over TLS, audio and video calls, hold/resume, mute, DTMF, the audio session helper, the CallKit adapter and the PushKit adapter.

Generate the Xcode project with [xcodegen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
cd Examples/SampleApp
xcodegen generate
open BaresipKitSample.xcodeproj
```

The project references the package at the repository root, so `Build/out/BaresipKitCore.xcframework` must exist (run `Build/build-xcframework.sh` first). Set your own bundle identifier and team for CallKit and PushKit; VoIP pushes also need the Push Notifications capability and a VoIP certificate on the server side.
