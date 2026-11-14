# Android setup

BaresipKit for Android: Kotlin libraries over a JNI bridge to the C core, with the same features
and types as the [Swift package](iOS.md). Names follow each language's conventions: acronyms
longer than two letters are capitalized like words in Kotlin, so Swift's `BaresipDTMFReply`,
`BaresipTLSConfiguration` and `BaresipICEState` are `BaresipDtmfReply`, `BaresipTlsConfiguration`
and `BaresipIceState` here. What Semantic Versioning covers is in [STABILITY.md](STABILITY.md). This guide covers installing the libraries,
a quick start, the setup recipes, the sample app, building from source, tests and releases. How
the two platforms share the core and differ where they must is in [Platforms.md](Platforms.md).

> [!IMPORTANT]
> **Beta.** There is no release yet, and the API can still change. The Android SDK has run in
> CI, on the JVM and on an emulator, but not yet on a physical device. Test it with your own
> devices and SIP server before relying on it.

## Modules

| Artifact | What it gives you | Add it when |
|---|---|---|
| `baresipkit` | `BaresipEngine`: accounts, calls, media, messages, events as a `Flow`, logging (Logcat, files), TLS, NAT, network and app lifecycle helpers; `BaresipCallController`, `SipIdentity` | Always |
| `baresipkit-audio` | `BaresipAudioController`: audio focus, communication mode, earpiece, speaker, Bluetooth and wired outputs | You manage audio yourself (no Telecom) |
| `baresipkit-video` | `BaresipVideoView` (OpenGL ES), `BaresipCamera` (Camera2 into the engine's camera source) | You show or send video |
| `baresipkit-telecom` | `BaresipTelecomAdapter`: calls in Telecom through Jetpack core-telecom, push-to-INVITE matching; `BaresipRedialRequest` for calls asked for with a `sip:` or `tel:` intent | You want the system to know your calls (recommended) |
| `baresipkit-push` | `BaresipPushAdapter`: Firebase tokens as `Contact` parameters, pushed calls | You receive calls while the app is not running |
| `baresipkit-compose` | `BaresipPhone`, `BaresipPhoneCall`, `BaresipCallVideo`, `BaresipCameraPreview` | You build the UI in Compose |

## Requirements

- Android 9 (API 28) or later, on `arm64-v8a` or `x86_64`
- Kotlin with coroutines; Jetpack Compose for `baresipkit-compose`
- To build from source: JDK 21, the Android SDK and NDK, see [Building from source](#building-from-source)

## Installation

Releases will be published to Maven Central under `io.github.mariokovacevic`; `baresipkit`
carries the native core for `arm64-v8a` and `x86_64`. There is no release yet. Until the first
one, build the core and publish the libraries to your local Maven repository:

```bash
git clone https://github.com/mariokovacevic/baresipkit.git
cd baresipkit
PLATFORM=android MODULE_SET=full ANDROID_NDK_HOME="$ANDROID_HOME/ndk/30.0.16248370" Build/build-xcframework.sh
cd Android && ./gradlew publishToMavenLocal
```

Then add the libraries you need, with the version in `Android/gradle.properties`:

```kotlin
repositories {
    mavenLocal()
}
dependencies {
    implementation("io.github.mariokovacevic:baresipkit:0.1.0-SNAPSHOT")
    implementation("io.github.mariokovacevic:baresipkit-telecom:0.1.0-SNAPSHOT")
    implementation("io.github.mariokovacevic:baresipkit-compose:0.1.0-SNAPSHOT")
}
```

## Quick start

```kotlin
val engine = BaresipEngine(BaresipConfiguration(userAgent = "MyApp"))
engine.setLogHandler(BaresipLogcat.handler())
engine.start()
val account = engine.addAccount(BaresipAccountConfiguration(aor = "sip:alice@example.com", authPassword = password))
engine.register(account)
engine.events.collect { event ->
    when (event) {
        is BaresipEvent.IncomingCall -> engine.answer(event.info.id)
        is BaresipEvent.Call -> println("${event.call}: ${event.state}")
        else -> Unit
    }
}
```

Every operation is a `suspend` function that runs on the engine's own thread; what happens
afterwards arrives through `events`. Only one engine runs per process; close it with `close()`.

## Setup recipes

**Telecom.** Create one `BaresipTelecomAdapter` and use it as the call controller, so answer,
end, hold and mute go through the system. The app shows incoming calls itself, as self-managed
calls require: post a `CallStyle` notification with a full-screen intent from `onIncomingCall`.

```kotlin
val telecom = BaresipTelecomAdapter(context, engine) { call -> showIncomingCall(call) }
val phone = BaresipPhone(engine, telecom, viewModelScope)
viewModelScope.launch { phone.run() }
val call = phone.makeCall("sip:door@example.com", video = true)
```

**Push.** Forward your `FirebaseMessagingService` to `BaresipPushAdapter`; it keeps the
account's `Contact` parameters (`pn-type=firebase`, `pn-tok`, `app-id`) current and reports a
pushed call to Telecom before waking the engine. A server matches the INVITE to the push by the
UUID in an INVITE header (`BaresipTelecomConfiguration.callUuidHeader`) or by the caller. The
door stack in `Tools/DoorStack` sends such pushes, to Google or to a local stand-in. A call the
server replaces with an INVITE carrying `Replaces`, or one the other side transfers with REFER,
keeps its Telecom call: the new call's `BaresipCallInfo.replacesCallId` names the old one, which
ends with `BaresipCallEndReason.REPLACED`, and the adapter moves the Telecom call over.

```kotlin
val push = BaresipPushAdapter(engine, appId = context.packageName) { call ->
    telecom.reportIncomingCallFromPush(call.uuid, call.remoteUri, call.displayName, call.hasVideo)
}
push.bind(account)
```

**Calls asked for outside the app.** Add an intent filter for `VIEW` and `DIAL` with the `sip`
and `sips` schemes (and `tel` if the app should be offered for phone numbers), and receive
`CALL` on an `activity-alias` that requires `android.permission.CALL_PHONE`, so only apps
allowed to place calls, like the Phone and contacts apps, can start one. Read the request with
`BaresipRedialRequest.from(intent)` in `onCreate` (only when `savedInstanceState` is `null`
and the activity was not launched from history, so a recreated activity does not call again)
and in `onNewIntent`. Call `request.destination` at once only when `request.callsNow` is set
and the intent reached the alias; otherwise show the destination and let the user start the
call.

**Audio without Telecom.** `BaresipAudioController(context, engine).activate()` requests audio
focus for voice communication, sets `MODE_IN_COMMUNICATION` and tells the engine;
`selectOutput` picks the earpiece, the speaker or a headset.

**Video.** Call `BaresipCamera.install(context)` once (the app needs the `CAMERA` permission),
then show a call's video with `BaresipCallVideo(engine, call)` in Compose or a
`BaresipVideoView` attached with `engine.setVideoRenderer(view.renderer, call)`. H.264 is coded
by MediaCodec and VP8 by libvpx.

**Network and lifecycle.** `BaresipNetworkMonitor(context, engine).start()` tells the engine
when the default network changes, so registrations and calls move to it.
`BaresipAppLifecycle(engine).start()` suspends the engine or takes it offline in the background
when no call runs.

## App checklist

Before shipping a VoIP app built on BaresipKit for Android:

| Where | What |
|---|---|
| Manifest | `INTERNET`, `ACCESS_NETWORK_STATE` and `RECORD_AUDIO`; `CAMERA` for video (merged from `baresipkit-video`); `MODIFY_AUDIO_SETTINGS`, and `BLUETOOTH_CONNECT` for Bluetooth headsets |
| Manifest | For Telecom: `MANAGE_OWN_CALLS`, and a foreground service of type `phoneCall` (with `microphone` and `camera` for video calls) with the matching `FOREGROUND_SERVICE_*` permissions |
| Manifest | For incoming calls: `POST_NOTIFICATIONS` and `USE_FULL_SCREEN_INTENT`, so the ring screen shows over the lock screen |
| Runtime | Ask for the microphone, camera and notification permissions before the first call |
| Firebase | A Firebase project, its `google-services.json`, and a `FirebaseMessagingService` that forwards tokens and messages to `BaresipPushAdapter`; send calls as high-priority data messages |
| SIP server | Reads the push parameters from the `Contact` and sends a push for a call to a registered device |
| Calls from other apps | The `sip:` and `tel:` intent filters and the `CALL_PHONE` alias from the recipe above |
| Licenses | Ship the third-party notices, including OpenSSL's NOTICE (see [License](../README.md#license)) |

## Sample app

[Android/zvono](../Android/zvono/README.md) is Zvono, the intercom sample, in Compose: doors with their last
picture and Open, activity, keypad, messages, settings and diagnostics, the ring screen with a
preview before answering, and the call screen with captions and chat for SIP messages. It uses
every module above. CI runs its screenshot test on an emulator and keeps the pictures as the
`android-sample-screenshots` artifact.

## Building from source

Requirements: JDK 21, the Android SDK with platform 36, NDK `30.0.16248370` and CMake 3.22.1,
and `cmake` and `nasm` on the build machine.

Build the C core for both Android ABIs first, from the repository root:

```bash
PLATFORM=android MODULE_SET=full ANDROID_NDK_HOME="$ANDROID_HOME/ndk/30.0.16248370" Build/build-xcframework.sh
```

Then build the libraries:

```bash
cd Android && ./gradlew assembleDebug
```

The API documentation is generated with Dokka:

```bash
cd Android && ./gradlew :dokkaGeneratePublicationHtml
```

## Tests

The JVM unit tests load the JNI bridge built against the core for the Linux host. Build that core
once, then run the tests:

```bash
PLATFORM=host MODULE_SET=full Build/build-xcframework.sh
```

```bash
cd Android && ./gradlew testDebugUnitTest
```

On other hosts the tests that need the core are skipped. The call tests talk to a small scripted
SIP peer over UDP on the machine's own address. The instrumented tests run on an emulator in CI;
one of them sends a call's H.264 video through a peer that echoes it, so MediaCodec encodes and
decodes it.

## Releasing

The `Release Android` workflow publishes the artifacts to Maven Central from the default branch
once CI passed for the commit. It needs the secrets `MAVEN_CENTRAL_USERNAME` and
`MAVEN_CENTRAL_PASSWORD` (a Central Portal token) and `SIGNING_KEY` and `SIGNING_KEY_PASSWORD`
(an ASCII-armored GPG key).

## Documentation

| Where | What |
|---|---|
| Dokka (`./gradlew :dokkaGeneratePublicationHtml`) | The API reference of every library |
| [Platforms.md](Platforms.md) | How the platforms share the core, the decisions behind the Android SDK, and parity with iOS type by type and test by test |
| [Architecture.md](Architecture.md#android) | The layers on Android, from the C core to the adapters |
| [C-ABI.md](C-ABI.md) | The C ABI the JNI bridge binds |
| [Troubleshooting.md](Troubleshooting.md) | Reading the log and the usual registration, media and ICE failures; the examples use the Swift names, which Kotlin shares |
| [Interop.md](Interop.md), [Limitations.md](Limitations.md) | Servers and devices BaresipKit has been tried with, and the known limits |
