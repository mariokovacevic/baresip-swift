# Platforms

How BaresipKit spans iOS and Android: one C core with two SDKs on top. The Swift package came
first; this document records why the Android SDK exists, the decisions behind it, how it was
built, and how the two SDKs match, type by type and test by test. To use either SDK, start with
its setup guide: [iOS.md](iOS.md) or [Android.md](Android.md).

Status: every phase below is done. The libraries and Zvono run in CI, the JVM tests against the
host core and the UI tests on an emulator; nothing has run on a physical Android device yet.

## Why

BaresipKit started as an open-source SIP SDK for iOS over baresip and libre. Android gets the same SDK,
with the same features, for any developer who builds a VoIP or intercom app. The C core, the
patches and the tests are shared; only the layers that talk to the operating system differ.

## Goals

- Everything the iOS SDK does, on Android: accounts and registration over UDP, TCP and TLS with
  private CAs, client certificates and SPKI pins; push `Contact` parameters; audio and video
  calls with Opus, G.722, G.711, H.264 and VP8; early media preview; DTMF (RFC 4733 and SIP
  INFO); hold, resume and music on hold; mute; blind and attended transfer; SIP MESSAGE; call
  statistics and recording; ICE, STUN and TURN over UDP, TCP and TLS with ICE restart on network
  change; SRTP; session timers; calls answered or declined elsewhere; logging with redaction.
- The system integration Android has in place of CallKit, PushKit and the audio session: a
  self-managed `ConnectionService`, push through Firebase Cloud Messaging, audio focus and
  routing, and the pushed-call matching the iOS adapters share.
- A Compose layer like `BaresipKitSwiftUI`, and the Zvono intercom sample for Android with the
  same design.
- The same quality bar as iOS: CI, tests at every layer, documentation.

## Non-goals

- A different feature set or API shape from iOS where Android does not force one.
- Java-first APIs; the API is Kotlin, usable from Java where it costs nothing.
- Devices below Android 9 (API 28). baresip's `aaudio` module needs API 28 for the
  voice-communication usage, input preset and audio session it sets.

## Anti-goals

- Forking the C core or the patches for Android. A fix in the core is a fix on both platforms.
- Naming any vendor whose devices are used for testing.

## How it is built (decisions)

1. **One repository.** Android lives under `Android/` next to the Swift package, and builds the
   same `Core/`, `Patches/` and pinned sources (`Build/versions.env`). Alternative: a separate
   repository with the core as a submodule; rejected because every core change would need two
   synchronized pull requests. With Android in it, the repository was renamed from
   `baresip-swift` to `baresipkit`.
2. **Kotlin over JNI over the C ABI.** `baresip_kit.h` is the contract, exactly as for Swift:
   a small JNI bridge in C turns `bsk_*` calls and `bsk_event` values into Kotlin calls and
   objects, and the Kotlin layer mirrors the Swift API (`BaresipEngine`, `BaresipConfiguration`,
   `BaresipEvent` as a sealed class, `suspend` functions for `async`, `Flow` for `AsyncStream`).
   Alternatives: SWIG or a generated binding (opaque, hard to keep idiomatic); writing the
   facade again in Kotlin (doubles the logic). Rejected.
3. **Gradle modules mirroring the Swift products:** `baresipkit` (engine, accounts, calls,
   messages, TLS, logging, network), `baresipkit-audio` (audio focus, routing, Bluetooth),
   `baresipkit-video` (rendering, camera), `baresipkit-telecom` (ConnectionService, the
   counterpart of CallKit and LiveCommunicationKit), `baresipkit-push` (FCM and push `Contact`
   parameters, the counterpart of PushKit), `baresipkit-compose` (the counterpart of
   `BaresipKitSwiftUI`), and the sample app `zvono`.
4. **Native build:** `PLATFORM=android Build/build-xcframework.sh` cross-compiles OpenSSL, Opus,
   libvpx, libre, baresip (with every patch) and the core with the NDK for `arm64-v8a` and
   `x86_64`, with the same pins and patches as for Apple. Gradle links the result into
   `libbaresipkit.so` with the JNI bridge, and the AAR carries it for both ABIs. Alternative: a
   separate `build-android.sh`; rejected because it would duplicate the fetching, pinning and
   patching.
5. **Platform modules in C, next to their Apple counterparts:** audio through baresip's `aaudio`
   module (patched if needed), H.264 through a new `mediacodec` module (the counterpart of
   `vidtoolbox`), the camera through a new `bskcamera` source fed from Camera2, and TLS trust of
   the system store through a callback into Kotlin (the counterpart of `bsk_trust.c`).
6. **minSdk 28, compileSdk 36, Kotlin with coroutines, Compose for UI.** Packages and the
   Maven group are `io.github.mariokovacevic.baresipkit`, the namespace Maven Central verifies
   for this GitHub account; the build uses the Gradle wrapper (8.14.3), the Android Gradle
   plugin 8.13 and NDK r30.
7. **Tests without a device first:** the JNI bridge also builds for the Linux host, so the
   Kotlin layer runs its unit tests on the JVM against the real core (calls between two engines,
   as `Tests/Core` does in C). Instrumented tests on an emulator come with audio, video and
   telecom.

## Phases, as built

Each phase ended green in CI and was usable on its own.

1. **Groundwork.** This plan; network access for the Android SDK and NDK; `Android/` Gradle
   project with the modules above, empty; CI job that builds it.
2. **Native core for Android.** `PLATFORM=android` in the build script; the core and its
   dependencies for both ABIs; the host build of the JNI bridge for JVM tests.
3. **Kotlin core API.** Engine lifecycle, configuration, logging, accounts and registration, TLS
   with CA, client certificate and pins, events as a `Flow`, calls (place, answer, reject, hang
   up, hold, resume, mute, DTMF, statistics, recording, transfer), SIP MESSAGE, network change,
   session timers, end reasons. Tests on the JVM against the core, as the Swift tests do.
4. **Audio.** `aaudio` in the module set, `BaresipAudioController` for focus, mode, speaker,
   earpiece and Bluetooth, music on hold. Which audio module works better on real devices
   (`aaudio` or `opensles`) is decided by testing on devices.
5. **Video.** Rendering into a `GLSurfaceView`, the camera through Camera2 into the core's
   `bskcamera` source, the `mediacodec` H.264 module, VP8, early video, bitrate adaptation.
   An instrumented test on an emulator sends a call's H.264 video through a peer that echoes it
   back, so MediaCodec encodes and decodes it.
6. **Telecom and push.** `BaresipTelecomAdapter` adds calls to Telecom through Jetpack's
   `CallsManager`, which runs a self-managed `ConnectionService` underneath, with the
   push-to-INVITE matching ported from `BaresipKitSystemCall` and calls answered or declined
   elsewhere; `BaresipPushAdapter` keeps the push `Contact` parameters current and reports
   pushed calls, fed by the app's `FirebaseMessagingService` without a Firebase dependency.
   Telecom has no Recents for self-managed calls; `BaresipRedialRequest` reads the call a
   `sip:`, `sips:` or `tel:` intent asks for (links, contacts, and the call log where the Phone
   app forwards it), the counterpart of the iOS request from Recents. The door
   stack's push gateway learns FCM with the sample app.
7. **Compose layer.** `BaresipPhone` and `BaresipPhoneCall` as Compose state holders with the
   same rules as the Swift versions (active call, held call resumed, controller actions, mute
   from the system, door-code DTMF replies, message peer matching), and `BaresipCallVideo` and
   `BaresipCameraPreview` composables. The Swift tests are ported one to one.
8. **Zvono for Android.** The sample with the intercom design: doors, activity, keypad,
   messages, settings, ring screen with preview, call screen with captions and chat, open door.
   UI test and screenshots in CI.
9. **Documentation and release.** The README in `Android/` as the integration guide, API docs
   with Dokka, and publishing to Maven Central with the `Release Android` workflow (the Maven
   publish plugin, Central Portal, signed artifacts with sources and Dokka javadoc jars).

## Parity with iOS

Every public type of the Swift package has a Kotlin counterpart with the same name and meaning,
apart from these platform differences:

| iOS | Android | Why |
|---|---|---|
| `BaresipCallKitAdapter`, `BaresipLiveCommunicationAdapter` | `BaresipTelecomAdapter` | One system call framework on Android (Jetpack core-telecom) |
| `BaresipAudioSessionController` | `BaresipAudioController` | Audio focus and `AudioManager` instead of `AVAudioSession` |
| `BaresipPushKitAdapter` | `BaresipPushAdapter` | Firebase Cloud Messaging instead of VoIP pushes |
| `BaresipOSLog` | `BaresipLogcat` | The system log of each platform |
| `BaresipCertificateError` | `BaresipCertificateException` | Kotlin names failures as exceptions |
| `BaresipRedialRequest(activity:)` | `BaresipRedialRequest.from(intent)` | iOS continues the app with a user activity from Recents, Android with a `sip:`/`tel:` intent |
| `BaresipVideoFrame.pixelBuffer` | `BaresipVideoFrame.planes` | `CVPixelBuffer` exists only on Apple platforms |
| `CallKit` settings `ringtoneSound`, `iconTemplateImageData`, `includesCallsInRecents`, `maximumCallsPerCallGroup` | none | Self-managed Telecom calls have no system ringer, icon, Recents or call groups; the app rings and shows the call itself (Zvono does) |
| `BaresipAppLifecycle.disconnectsOnTermination` | none | Android does not tell an app reliably that it is being ended, so there is no moment to unregister; registrations expire on the server |

Zvono mirrors the iOS sample screen by screen, including the git-ignored deployment profile
(`AppProfile`, `Android/zvono/src/local/`), redial from outside the app, the ring picture in the
notification (the iOS notification content extension), launcher shortcuts for doors (the iOS Open
Door intent) and the call integration switch (the iOS call screen choice).

## Behavioral parity, test by test

Every iOS test suite in `Tests/BaresipKitTests` has its Android counterpart, which checks the
same behaviour through the Kotlin API:

| iOS tests | Android tests | Notes |
|---|---|---|
| `AccountConfigurationTests`, `ContactParameterTests` (8) | `AccountConfigurationTest` (7), `EventDecoderTest.hugeDurationsAreClamped` | Same validation, secure defaults, `Contact` parameter encoding, clamped durations |
| `EngineLifecycleTests` (4) | `EngineLifecycleTest` (6) | Plus a closed engine and unknown calls |
| `AppLifecycleTests` (5) | `AppLifecycleTest` (4) | No `TerminationStopsTheEngine`: Android has no reliable termination callback |
| `CallEndReasonTests` (3), `NetworkEventTests` (2) | `EventDecoderTest` (7), `EngineLifecycleTest.capabilitiesAndVersions` | Answered or declined elsewhere, network events, ABI version |
| `FileLogTests` (5) | `FileLogTest` (5) | One to one |
| `CertificatesTests` (11) | `CertificatesTest` (7) | Kotlin takes non-null bundles, so the nil cases do not exist |
| `NetworkMonitorTests` (5) | `NetworkMonitorTest` (3) | Same rules for first, changed, lost and repeated networks |
| `VideoSinkTests` (7) | `VideoTest` (3), `VideoGeometryTest` (8), `H264LoopbackTest` (emulator), `EventDecoderTest` | `CVPixelBuffer`/IOSurface cases are Apple only; Android adds rendering geometry and MediaCodec H.264 |
| `AudioInterruptionTests` (6), `AudioOptionsTests` (4) | `AudioControllerTest` (7) | Focus loss pauses, regained focus resumes only what the controller activated, Telecom-owned audio waits; iOS media-services reset and Bluetooth profile flags have no Android counterpart |
| `CallKitActionResultTests` (9), `LiveCommunicationAdapterTests` (8) | `TelecomActionsTest` (4), `DisconnectCauseTest` (3), `PushCallLedgerTest` | Successful, refused and timed-out actions, abandoned starts, calls ended elsewhere, SIP URI or number handles; ending an unknown call succeeds |
| `PushCallLedgerTests` (22), `PushMatchTests` (8) | `PushCallLedgerTest` (21), `PushMatchTest` (7) | Ported one to one |
| `ContactParameterUpdatesTests` (7), `IncomingPushReportTests` (2) | `PushTest` (5) | PushKit's "report before returning" rule does not apply to FCM |
| `BaresipPhoneTests` (14), `BaresipPhoneControlTests` (16), `MessagePeerTests` (4) | `BaresipPhoneTest` (12), `BaresipPhoneControlTest` (18) | Ported one to one; snapshot cases merged |
| `RedialRequestTests` (3) | `BaresipRedialRequestTest` (5), `RedialTest` (emulator) | Intents instead of user activities, with the trusted `CALL` rule |
| Calls against a SIP peer (C suite, `test_call.c`) | `CallTest`, `OutgoingCallTest` (JVM against the host core) | Incoming and outgoing calls, hold, mute, DTMF in RTP and SIP INFO, messages, rejection |
| Sample app UI test (`RegistrationCallUITests`) and screenshots | Zvono `RegistrationCallTest`, `ScreenshotTest`, `RedialTest`, 34 unit tests | TLS registration with a private CA, a wrong SPKI pin failing and clearing it, a call through the registrar to a peer on the host that runs until media flows, and every screen of the iOS sample. The emulator's NAT hides the phone's own address, so the Android call takes its media through a TURN relay (coturn) on the runner |

## Open questions

What the emulator cannot show is still to be tried on physical devices: whether `aaudio`, which
the module set uses today, or `opensles` works better, Bluetooth routing, the camera, Firebase
pushes from Google's servers, and Telecom on vendor builds of Android.
