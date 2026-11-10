# Sample app

A SwiftUI app built on the SDK, laid out like the system Phone and Settings apps:

- **Calls**: account status, a dial card (audio, video, message, DTMF), the list of calls (direction, peer, duration, codec; switch, hold or resume, hang up from the context menu) and the latest message.
- **Recent calls**: past calls with direction, video, time, duration and any DTMF result, kept across launches; tapping one repeats it (audio, video or the same DTMF) or puts the address in the dial card.
- **DTMF**: sends a code on the current call, or calls the entered address and sends it once connected (SIP INFO when the peer offers no telephone-event), waits for the station's reply digit and hangs up, like a door opener.
- **In call** (full screen): caller, duration, encryption, codec and ICE path, live loss, jitter, RTT and MOS, then mute, keypad, audio output (iPhone, speaker, headphones, Bluetooth, car or the system route picker), hold, video and transfer, record (stereo WAV in Documents/Recordings, visible in the Files app), switch camera and restart ICE when they apply, and hang up; the chevron returns to the call list while the call goes on.
- **Your camera**: while the camera is sent, a picture of it sits in the top right corner of the call screen (`BaresipSelfView`), mirrored for the front camera; tap it to switch cameras.
- **Background**: with no call running, the app unregisters when it moves to the background and registers again when it is active, and unregisters when it terminates (`BaresipAppLifecycle` with `.goOffline`). It is not reachable by VoIP push while in the background.
- **Incoming call**: every incoming call is previewed, receiving the caller's video and audio before answering without sending yours, then Answer or Decline. On a phone iOS plays the audio only once CallKit answers the call; the simulator plays it while ringing. Account chooses whether the preview receives audio, and the log shows what each preview receives.
- **Transfer**: consult first (the call goes on hold, the target is called) and complete the attended transfer, end the consultation, or transfer blind.
- **Messages**: conversations and a thread view with delivery status for SIP messages.
- **Engine state** (toolbar, top left): registrations and active calls as `BaresipKitSwiftUI` reports them, with mute, hold and hang up. `CallModel` keeps one `BaresipPhone` per engine and runs it while the engine runs.
- **Account**: domain, transport, port, outbound proxy, credentials (Keychain), server CA (PEM or DER), client certificate (imported or pasted as PEM), SPKI pins, media encryption, and settings for testing: NAT traversal (none, STUN, ICE with TURN, relay only), rtcp-mux, NAT pinhole, RTP timeout, IPv6, SIP Outbound, registration time, DTMF method, transfers, codec order and video size, frame rate, bitrate and adaptive bitrate. Engine settings (relay only, IPv6, video) restart the engine when saved. Certificates and the client key are kept in app storage that can be read once the phone has been unlocked after a restart, because a VoIP push starts the app on a locked phone, and are left out of backups; they are deleted only when you remove them. Everything entered is saved as you type.

It also shows the audio session helper, the CallKit adapter, the PushKit adapter and network change handling.

Sources are grouped as `App` (entry point), `Model` (call model, settings and storage) and `Views` (`Calls`, `Messages`, `Account`, `Common`).

Generate the Xcode project with [xcodegen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
cd Examples/SampleApp
xcodegen generate
open BaresipKitSample.xcodeproj
```

The project references the package at the repository root, so `Build/out/BaresipKitCore.xcframework` must exist (run `Build/build-xcframework.sh` first). Set your own bundle identifier and team for CallKit and PushKit; VoIP pushes also need the Push Notifications capability and a VoIP certificate on the server side.

The XCFramework ships an arm64 simulator slice only, so the project excludes x86_64 for simulator builds. Build `SLICES="ios-arm64 ios-arm64-simulator ios-x86_64-simulator"` if you need Intel simulators.

## Logs

The app writes its log to one file per day in `Library/Logs`, keeps the last seven days and passes every line to the system log; **Log** shows the latest lines and shares the files. The log holds the registration and call events of the SDK with the account address and the addresses of the people you call or who call you.

**Log SIP messages** (in Log) adds every SIP message sent and received. It is off in release builds and on in debug builds until you change it, and a change applies the next time the app starts. SIP messages contain the numbers and addresses dialled, the names and addresses of callers, IP addresses, the SDP of every call and the text of SIP MESSAGE chats; digits sent as DTMF over SIP INFO, such as a door code, appear in them as plain text. The SDK redacts credentials, push tokens and SRTP keys, but not these. Turn it on to diagnose a problem, and look through a log before you share it.

## UI test

`UITests/RegistrationCallUITests.swift` drives the app on a simulator: it enters the domain, port, username and password, registers over TLS against a server whose self-signed certificate is the app's CA, checks that a wrong SPKI pin makes registration fail and that clearing it registers again, then places an audio call to a peer and hangs up. CI runs it on macOS against `Tools/ContactParameterProof/tls_registrar.py` and the `bsk_test_call peer` binary on the runner. To run it yourself, start both on your Mac and pass `TEST_RUNNER_BSK_UITEST_HOST=<mac ip>` and `TEST_RUNNER_BSK_UITEST_CA_PEM="$(cat cert.pem)"` to `xcodebuild test`. With `BSK_UITEST=1` in its launch environment a debug build starts with empty settings, takes the CA from `BSK_UITEST_CA_PEM`, uses generated audio instead of the microphone and places calls without CallKit. The test CA and anything else imported during the test go to a temporary directory, not to the app's certificate storage, which the test neither reads nor changes. Release builds ignore both variables. In the simulator the app also places calls without CallKit, because CallKit never activates the audio session there.

## Testing against your own deployment

A git-ignored `Local/` folder adapts the sample to a particular SIP deployment without changing
its code:

1. Copy `project.local.example.yml` to `project.local.yml` and fill in your bundle identifier,
   team and entitlements. `project.local.yml` and `Local/` are ignored by git.
2. Put Swift files in `Local/Sources/`. A class named `BSKLocalAppProfile` that conforms to
   `AppProfile` changes the engine, account and CallKit configuration, the push `app-id`, how VoIP
   push payloads are read, and adds its own section to the Account screen:

   ```swift
   @objc(BSKLocalAppProfile)
   final class MyProfile: NSObject, AppProfile {
       override required init() { super.init() }
       func configure(_ configuration: inout BaresipConfiguration) { configuration.maxCalls = 2 }
       func configure(_ account: inout BaresipAccountConfiguration) {}
       func configure(_ callKit: inout BaresipCallKitConfiguration) {}
       var pushAppID: String { "com.example.app.voip" }
       static func caller(in payload: [AnyHashable: Any]) -> (uri: String?, name: String?) {
           (payload["from"] as? String, nil)
       }
       func accountSection(model: CallModel) -> AnyView? { nil }
   }
   ```

3. Generate with `xcodegen --spec project.local.yml`. Without it, `xcodegen` builds the plain
   sample.
