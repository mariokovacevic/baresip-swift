# Device testing

GitHub Actions covers the C core, the Swift package, the simulator tests, the sample app UI test and the Asterisk and coturn integration suite. This checklist covers what needs a physical iPhone: the camera, real audio, CallKit, PushKit and a real SIP server.

## Setup

1. On a Mac with Xcode, build the core: `Build/build-xcframework.sh`.
2. Install XcodeGen (`brew install xcodegen`), then in `Examples/SampleApp` set your bundle identifier and development team in `project.yml` and run `xcodegen generate`.
3. Build and run the sample app on an iPhone with iOS 16 or later.
4. Without a SIP server of your own, run a local one on the Mac: `Scripts/dev-pbx.sh start` starts the Asterisk and coturn setup of the integration tests, creates a certificate for the Mac's address and prints the account settings, the CA file to import on the phone and the numbers to call (`echo`, `early`, `alice`, `bob`). The phone must be in the same network. It needs Docker with host networking: on Linux as is, in Docker Desktop for Mac after turning on host networking (Settings, Resources, Network). `Scripts/dev-pbx.sh stop` stops it.
5. Enter the SIP account in the app's Account screen. Import the server's CA certificate from Files if it uses a private CA. Never write the password into a file or a log.

Collect the app log from the Mac while testing:

```bash
log stream --predicate 'subsystem == "com.example.BaresipKitSample"'
```

## Checklist

Record pass or fail and notes for each item, with the device model, iOS version and SIP server.

1. Registration over TLS, including after importing a CA certificate; with a wrong SPKI pin it must fail with a TLS error, and register again once the pin is removed. If the server asks for a client certificate, also with one imported.
2. Outgoing audio call with two-way audio, then mute and unmute.
3. Speaker on and off, and a Bluetooth headset if available.
4. Hold and resume; audio returns after resuming.
5. DTMF `1`, `2`, `3`, `#` heard or registered on the far end.
6. Outgoing video call: remote video in the app, the local camera visible on the far end, switching between the front and back camera.
7. Incoming call in the foreground, answered and rejected. Tap Preview first: you hear, and for video see, the caller before answering while they do not hear you. Repeat with "Preview incoming calls automatically" turned on.
8. CallKit: the call appears on the lock screen and the call screen, and the audio session activates only after answering.
9. Messages: a SIP message arrives on the far end and shows "Delivered"; a reply arrives in the app.
10. Attended transfer: during a call, Consult a third number, talk, then Complete transfer; the first and third parties are connected and your calls end.
11. Network change during a call: with ICE turned on (optionally with a TURN server), start an audio call on Wi-Fi and turn Wi-Fi off; audio returns within a few seconds and the log shows an ICE restart and a new connected ICE event.
12. Video on a weak link: with packet loss added (for example with Network Link Conditioner), the video target bitrate in the call statistics drops, and rises again afterwards.
13. Rendering cost: with remote H.264 video on screen, Instruments (Time Profiler) shows no `CVPixelBufferCreate` calls for remote frames.
14. Recording: record a call across hold and resume; the WAV file in Files has your voice on the left channel and the other party on the right.
15. Logs: no password, `Authorization` header or full push token appears in the log.
16. Push, if you have a VoIP push certificate and a push sender: a VoIP push while the app is in the background reports the call, and answering connects it.
