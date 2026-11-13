# Sample app

A SwiftUI app built on the SDK, shown as Zvono, a video intercom for residents: dark, with brass
for ringing and opening doors, a bell with a keyhole as its icon, and five tabs.

- **Doors**: the saved doors, each in one row with a small last picture from its camera (small,
  so it does not pass for a live view), when it last rang, and Open, which calls the door, sends
  its code once connected and hangs up. Tapping the picture calls the door to look. Above them, whether rings reach the phone, and below, today's activity.
  Without an account the tab shows the setup screen instead: server, user, password and
  transport, then Connect.
- **Door** (from Doors or Settings): name, SIP user or address, the code (DTMF), whether the
  notification of a ring offers Open door, Face ID before opening from the app, hanging up after
  opening, and whether the door has a camera. A call is matched to a door by its SIP user.
- **Activity**: past calls, kept across launches, as missed rings, opened doors, talks with a
  door and ordinary calls, with the caller's picture, filters and a button that repeats the
  call or the opening. A tap offers audio, video, the same DTMF again, or the address on the
  keypad.
- **Keypad**: any number or SIP address, then Call, Video or Message, and Call, send a code,
  hang up: a code on the current call, or on a new call once connected (SIP INFO when the peer
  offers no telephone-event), waiting for the station's reply digit if one is set.
- **Messages**: conversations and a thread view with delivery status for SIP messages; a message
  that was not delivered can be sent again.
- **Settings**: the account and its registration, what happens when a door rings (stay reachable
  by push, hear the door before answering, picture in the notification), the doors, and
  Diagnostics.
- **Account** (from Settings): domain, transport, port, outbound proxy, credentials (Keychain),
  server CA (PEM or DER), client certificate (imported or pasted as PEM), SPKI pins, media
  encryption, and settings for testing: NAT traversal (none, STUN, ICE with TURN, relay only),
  rtcp-mux, NAT pinhole, RTP timeout, IPv6, SIP Outbound, registration time up to a week, DTMF
  method, transfers, codec order and video size, frame rate, bitrate and adaptive bitrate.
  Engine settings (relay only, IPv6, video) restart the engine when saved. Certificates and the
  client key are kept in app storage that can be read once the phone has been unlocked after a
  restart, because a VoIP push starts the app on a locked phone, and are left out of backups;
  they are deleted only when you remove them. Everything entered is saved as you type.
- **Diagnostics** (from Settings): registrations and calls as `BaresipKitSwiftUI` reports them,
  with mute, hold and hang up, the network and push state, and the log with Share and the SIP
  message switch. `CallModel` keeps one `BaresipPhone` per engine and runs it while the engine
  runs.
- **Incoming ring** (full screen): the caller's name and how long it rings, See who is there to
  preview the call, receiving the caller's video and audio before answering without sending
  yours, then Decline, Answer and, for a door with a code, Open door (answers without the
  camera, sends the code and hangs up). On a phone iOS plays the audio only once CallKit answers
  the call; the simulator plays it while ringing.
- **In call** (full screen): the other side's video, your camera in the top right corner while
  it is sent (`BaresipSelfView`), the status and whether the call is encrypted, then mute, sound
  output (iPhone, speaker, headphones, Bluetooth, car or the system route picker), your camera,
  keypad, hold and More, and Open door for a door. More holds transfer (consult first or blind),
  recording (stereo WAV in Documents/Recordings, visible in the Files app), switching cameras,
  restarting ICE, the sound output and the call's quality: MOS, loss, jitter, round trip, codec
  and ICE path. The chevron returns to the app while the call goes on; with several calls the
  Doors tab leads to a list to switch, hold, connect the two and leave, or hang up. Calls start
  on the loudspeaker; held to the ear, the proximity sensor moves them to the earpiece and back,
  until the user picks an output in that call. A held call plays `Sounds/HoldMusic.wav` to the
  other side (`BaresipAudioConfiguration.holdMusicFile`; `Tools/Sounds/hold_music.py` makes it).
- **Ringtone**: Settings, Ringtone picks the iPhone's ringtone or one of the app's sounds (Chime,
  Bells, Classic; `Tools/Sounds/ringtones.py`); the choice goes to
  CallKit at once (`BaresipCallKitAdapter.setRingtoneSound(_:)`) and plays once as a preview.
  LiveCommunicationKit takes a ringtone only when its adapter is created, so there the engine
  restarts with the new one when no call runs.
- **Messages during a call**: a SIP MESSAGE from the other side of the call on screen appears
  over the video as a caption for a few seconds, at most three at a time, and VoiceOver reads
  it. The chat button in the call's header shows the unread messages from that side and opens
  the conversation as a sheet over the call, to read and reply while the call goes on. A
  message from anybody else only raises the badge of the Messages tab. In the background,
  where CallKit's or LiveCommunicationKit's call screen leaves the app, a message shows a
  notification instead.
- **Call screen**: Settings, Call screen picks CallKit or LiveCommunicationKit (iOS 17.4 or
  later) for the system call screen. The engine restarts with the chosen adapter when no call
  runs, and VoIP pushes are reported to it: to CallKit inside the PushKit delegate method, to
  LiveCommunicationKit through `BaresipPushKitAdapter.reportingAsynchronously`. The simulator
  shows no call screen, so there the choice changes nothing.
- **Contacts**: in Keypad and in Settings, people and desks with a name and a number or address,
  called, video called or written to with one touch.
- **Background**: with no call running, the app unregisters when it moves to the background and
  registers again when it is active, and unregisters when it terminates (`BaresipAppLifecycle`
  with `.goOffline`); it is then not reachable by VoIP push. **Reachable when Zvono is closed**
  in Settings keeps the registration on the server instead (`.suspend`), so a VoIP push can
  announce a call.
- **Ringing in the background** (prototype, see below): a call that rings with video while the
  app is in the background shows a notification with the caller's picture and Answer, Decline
  and, for a saved door with a code, Open door; touching and holding it shows newer pictures as
  they arrive.

It also shows the audio session helper, the CallKit adapter, the PushKit adapter and network
change handling.

Sources are grouped as `App` (entry point and tabs), `Model` (call model, doors, settings and
storage) and `Views` (`Doors`, `Activity`, `Keypad`, `Messages`, `Settings`, `Calls` and the
shared `Design`: colors, type, cards and buttons). Titles use Barlow Semi Condensed, bundled in
`SampleApp/Fonts` under the SIL Open Font License; the icon and the logo are in
`SampleApp/Assets.xcassets`.

Generate the Xcode project with [xcodegen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
cd Examples/SampleApp
xcodegen generate
open BaresipKitSample.xcodeproj
```

The project references the package at the repository root, so `Build/out/BaresipKitCore.xcframework` must exist (run `Build/build-xcframework.sh` first). Set your own bundle identifier and team for CallKit and PushKit; VoIP pushes also need the Push Notifications capability and a VoIP certificate on the server side.

The XCFramework ships an arm64 simulator slice only, so the project excludes x86_64 for simulator builds. Build `SLICES="ios-arm64 ios-arm64-simulator ios-x86_64-simulator"` if you need Intel simulators.

## Preview of a ringing call (prototype)

iOS shows its own call screen for a VoIP push and that screen cannot show a picture. The sample
adds its own layers around it:

1. The call is previewed while it rings, video only when the account receives no audio, also in
   the background. `CallPreviewFeed` is the call's renderer: it passes the frames to the incoming
   call screen and saves a JPEG of the video four times a second.
2. With the first picture and the app in the background, a notification shows the picture with
   Answer and Decline, and Open door when the call comes from a saved door with a code (answers
   without the camera, sends the code as DTMF and hangs up). A call that ends unanswered leaves its last picture in a
   "Missed ring" notification.
3. A tap opens the app on the incoming call screen with the live video.
4. Touching and holding the notification opens `PreviewExtension`, a notification content
   extension that shows the saved picture and replaces it as newer ones arrive. The app and the
   extension share the pictures through an app group; without one the extension shows the
   notification's own picture only.

To try it on a phone, use a local project (below) with your bundle identifiers, the Push
Notifications capability and an app group registered for your team (`BSK_APP_GROUP`), turn on
**Reachable when Zvono is closed** in Settings, and call the account from a device that offers
video while the app is in the background.

`Tools/DoorStack` runs what this needs on your computer: a PBX, a push gateway and a door
station simulator that rings with video and opens its door on a code.

The sample reads the call's UUID from the push payload (`uuid`) and from the INVITE header
`X-Call-UUID`, so a push and its INVITE are bound exactly when the server sends both, as the
door stack does. Callers with a numeric user are reported to iOS as phone numbers, so a contact
with the number `100` gives the call its name and photo. A tap on one of the sample's calls in
the Recents list of the Phone app opens the sample and calls again.

Not tried on a device yet:

- whether iOS shows the notification's banner while the banner of the ringing call is on screen;
- decoding video and drawing the pictures in the background (the pictures are drawn in software,
  as the GPU is not available there);
- how fast the extension follows the pictures.

On the Lock Screen the system call screen covers everything, so the preview is seen there only
after unlocking. The extension target uses the Swift 5 language mode; the app uses Swift 6.

## Logs

The app writes its log to one file per day in `Library/Logs`, keeps the last seven days and passes every line to the system log; **Log** shows the latest lines and shares the files. The log holds the registration and call events of the SDK with the account address and the addresses of the people you call or who call you.

**Log SIP messages** (in Settings, Diagnostics) adds every SIP message sent and received. It is off in release builds and on in debug builds until you change it, and a change applies the next time the app starts. SIP messages contain the numbers and addresses dialled, the names and addresses of callers, IP addresses, the SDP of every call and the text of SIP MESSAGE chats; digits sent as DTMF over SIP INFO, such as a door code, appear in them as plain text. The SDK redacts credentials, push tokens and SRTP keys, but not these. Turn it on to diagnose a problem, and look through a log before you share it.

## UI test

`UITests/ScreenshotTests.swift` takes screenshots of the screens, with demo doors, activity and messages that a debug build loads when launched with `BSK_DEMO=1`, a ring from `Tools/SampleScreenshots/ring.py` and a call to the test peer. CI puts them in the run's `sample-screenshots` artifact. On a Mac with Xcode and XcodeGen, run it yourself and watch it in Simulator, staying three seconds on each screen:

```bash
PAUSE=3 Tools/SampleScreenshots/run.sh
```

The script builds the XCFramework and the test peer when they are missing (the first time takes a while), starts a TLS registrar on port 5082, the ringing door on 5072 and the answering peer on 5070 on the Mac's LAN address, and opens the folder with the screenshots at the end. macOS may ask whether Python and `bsk_test_call` may accept incoming connections; allow them.

`UITests/RegistrationCallUITests.swift` drives the app on a simulator: it enters the domain, port, username and password, registers over TLS against a server whose self-signed certificate is the app's CA, checks that a wrong SPKI pin makes registration fail and that clearing it registers again, then places an audio call to a peer and hangs up. CI runs it on macOS against `Tools/ContactParameterProof/tls_registrar.py` and the `bsk_test_call peer` binary on the runner. To run it yourself, start both on your Mac and pass `TEST_RUNNER_BSK_UITEST_HOST=<mac ip>` and `TEST_RUNNER_BSK_UITEST_CA_PEM="$(cat cert.pem)"` to `xcodebuild test`. With `BSK_UITEST=1` in its launch environment a debug build starts with empty settings, takes the CA from `BSK_UITEST_CA_PEM`, uses generated audio instead of the microphone and places calls without CallKit. The test CA and anything else imported during the test go to a temporary directory, not to the app's certificate storage, which the test neither reads nor changes. Release builds ignore both variables. In the simulator the app also places calls without CallKit, because CallKit never activates the audio session there.

## Testing against your own deployment

A git-ignored `Local/` folder adapts the sample to a particular SIP deployment without changing
its code:

1. Copy `project.local.example.yml` to `project.local.yml` and fill in your bundle identifier,
   team and entitlements. `project.local.yml` and `Local/` are ignored by git.
2. Put Swift files in `Local/Sources/`. A class named `BSKLocalAppProfile` that conforms to
   `AppProfile` changes the engine, account, CallKit and LiveCommunicationKit configuration, the
   push `app-id`, how VoIP push payloads are read, and adds its own section to the Account
   screen:

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
