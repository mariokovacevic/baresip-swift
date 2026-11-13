# Zvono for Android

The Android version of the Zvono sample (`Examples/SampleApp`): a video intercom for residents,
dark, with brass for ringing and opening doors, built with Jetpack Compose on the BaresipKit
Android modules. The screens follow the iOS sample's README: Doors (with the setup screen when no
account is saved), Door, Activity, Keypad, Messages, Settings, Account, Ringtone, Diagnostics,
the incoming ring and the call screen with captions and the chat over the call.

```bash
cd Android
./gradlew :zvono:assembleDebug :zvono:testDebugUnitTest
```

## How it is put together

- `model/CallModel` and its `CallModel*.kt` extensions do what `CallModel` does on iOS: they create
  the `BaresipEngine`, run a `BaresipPhone` on it, register the account, and start
  `BaresipNetworkMonitor`, `BaresipAppLifecycle` (offline in the background, or suspended when
  **Reachable when Zvono is closed** is on), `BaresipAudioController` and
  `BaresipTelecomAdapter`, which takes the call actions. `BaresipCamera` is installed in
  `ZvonoApplication`.
- A ring shows the full-screen ring screen while Zvono is in the foreground. In the background the
  Telecom adapter's `onIncomingCall` posts a `CallStyle` notification with a full-screen intent,
  with Answer, Decline and, for a door with a code, Open door. A running call keeps a foreground
  service of type `phoneCall` with an ongoing `CallStyle` notification.
- A ring with video is previewed with early media (with the caller's audio when **Hear the door
  before answering** is on, otherwise video only, as on iOS). `CallPreviewFeed` is the call's
  renderer: it passes the frames on to the ring screen and saves a JPEG of the picture about four
  times a second. With **Picture in the notification** on and Zvono in the background, the ringing
  `CallStyle` notification shows the newest picture (large icon, caller icon and an expanded
  picture), at most once a second, with Answer, Decline and Open door. A ring that ends unanswered
  leaves a "Missed ring" notification with its last picture. A tap opens the ring screen with the
  live video.
- Calls start on the loudspeaker. During an audio-only call on the phone's own outputs, the
  proximity sensor moves the audio to the earpiece when the phone is held to the ear, turns the
  screen off with `PROXIMITY_SCREEN_OFF_WAKE_LOCK`, and goes back to the loudspeaker when it moves
  away, until the user picks an output in that call.
- Every saved door with a code gets a dynamic launcher shortcut, "Open <door>", the counterpart of
  the iOS Open Door intent: it opens the door the same way the Open button does, asking to unlock
  the phone first when the door says so. The shortcuts carry the `actions.intent.OPEN_APP_FEATURE`
  capability (`res/xml/shortcuts.xml`) for app shortcuts in Google Assistant.
- **Call integration** in Settings is the counterpart of the iOS call screen choice: **System
  (Telecom)** runs calls through `BaresipTelecomAdapter`; **In app only** runs them on the engine
  directly with `BaresipAudioController` taking the audio focus and the outputs. The engine
  restarts with the choice once no call runs.
- A `sip:` or `sips:` link, a contact's SIP address or a call the Phone app forwards opens Zvono
  with `BaresipRedialRequest`, the counterpart of the iOS redial from Recents. A link (`VIEW`
  or `DIAL`) only fills in the keypad. A `CALL` intent that reaches `CallAlias`, which requires
  `CALL_PHONE`, starts the call, after the account registers if it arrives earlier and the
  registration follows within 30 seconds.
- Settings, doors, contacts and the activity are kept in the app's private `SharedPreferences`
  as JSON. The SIP and TURN passwords and the client certificate with its key are encrypted with
  an AES key in the Android keystore (`system/AndroidStores.kt`). Backups are off.
- The log goes to `files/Logs` through `BaresipFileLog`; Diagnostics shares it through a
  `FileProvider`. Recordings go to the app's external files folder, `Recordings`.

## Push with Firebase

The repository cannot ship a `google-services.json`, so the app builds without Firebase.
`ZvonoApplication.push` is a `PushReceiver` that wraps `BaresipPushAdapter`: once it has a token
it adds the push parameters to the account's `Contact` and reports pushed calls to Telecom. To
receive pushes:

1. Create a Firebase project for the package `io.github.mariokovacevic.baresipkit.zvono` and put
   its `google-services.json` in `Android/zvono`.
2. Add the Google services Gradle plugin and `com.google.firebase:firebase-messaging` to
   `zvono/build.gradle.kts`.
3. Add a messaging service and declare it in the manifest with the
   `com.google.firebase.MESSAGING_EVENT` intent filter:

```kotlin
class ZvonoMessagingService : FirebaseMessagingService() {
    private val push get() = (application as ZvonoApplication).push

    override fun onNewToken(token: String) = push.pushTokenChanged(token)

    override fun onMessageReceived(message: RemoteMessage) {
        runBlocking { push.pushArrived(message.data) }
    }
}
```

The server sends data messages with `from`, `name`, `video` and `uuid`, as `BaresipPushCall`
reads them, and the INVITE carries the same UUID in `X-Call-UUID`.

## Screenshots

`src/androidTest/.../ScreenshotTest.kt` launches the app with empty settings, shoots the setup
screen, loads demo doors, activity and messages (`seedDemo`, debug builds only, no server
needed), then shoots the same screens as the iOS `ScreenshotTests`, including a demo ring, a demo
call, its More sheet, a caption and the chat over the call. The pictures land in the app's
external files folder, `screenshots`:

```bash
./gradlew :zvono:connectedDebugAndroidTest
adb pull /sdcard/Android/data/io.github.mariokovacevic.baresipkit.zvono/files/screenshots
```

Titles use Barlow Semi Condensed under the SIL Open Font License (`src/main/assets/fonts-OFL.txt`).

## A profile for your deployment

As on iOS, a git-ignored folder adapts Zvono to a particular SIP deployment without changing its
code. Put Kotlin files in `Android/zvono/src/local/kotlin/`; the build adds the folder when it
exists. A class `io.github.mariokovacevic.baresipkit.zvono.local.LocalAppProfile` that
implements `AppProfile` changes the engine, account and Telecom configuration and the push
`app-id`, and adds its own section to the Account screen:

```kotlin
package io.github.mariokovacevic.baresipkit.zvono.local

class LocalAppProfile : AppProfile {
    override fun configure(account: BaresipAccountConfiguration) =
        account.copy(contactParameters = account.contactParameters + BaresipContactParameter("x-site", "home"))

    override fun pushAppId(context: Context) = "com.example.intercom"

    override fun accountSection(): (@Composable (CallModel) -> Unit) = { Text("Example deployment") }
}
```

Without the class Zvono uses `DefaultAppProfile`, which changes nothing.

