# Audio Session

Keep the engine and `AVAudioSession` in step.

## Overview

The engine never activates the audio session itself. Audio for a call starts after
``BaresipEngine/audioSessionDidActivate()`` and stops at
``BaresipEngine/audioSessionDidDeactivate()``.

With CallKit, the system activates the session when the user answers or starts a call, and
`BaresipCallKitAdapter` forwards the provider's activation callbacks to the engine.

Without CallKit, use `BaresipAudioSessionController` from the `BaresipKitAudio` module:

```swift
import BaresipKitAudio

let audio = BaresipAudioSessionController(engine: engine)
try audio.configureForVoIP(allowBluetooth: true)
try await audio.activate()
try audio.setSpeakerEnabled(true)
```

The controller forwards route changes to the engine with
``BaresipEngine/audioRouteDidChange()``. It forwards a route change only when a device appeared
or went away; the category and configuration changes that starting the audio unit causes are not
forwarded, because restarting on them restarts the unit in a loop.

### Interruptions

When another app or a phone call interrupts the session, the controller pauses the engine's
audio with ``BaresipEngine/audioInterruption(began:)``. What happens when the interruption ends
depends on what iOS reports and on who activated the session:

- iOS does not ask the app to resume (the notification has no `shouldResume` option): the audio
  stays paused. Call `activate()` again when the call should continue.
- The controller activated the session with `activate()`: it activates the session again and
  then resumes the engine. If the activation fails, the audio stays paused until you call
  `activate()`.
- CallKit activated the session and you forwarded it with `didActivateFromCallKit()`: the
  controller waits for the next `didActivateFromCallKit()`, because only CallKit may activate
  the session of a CallKit call. With `BaresipCallKitAdapter` or
  `BaresipLiveCommunicationAdapter`, forward it with the adapter's `setAudioSessionHandler(_:)`:

  ```swift
  callKit.setAudioSessionHandler { active in
      if active {
          await audio.didActivateFromCallKit()
      } else {
          await audio.didDeactivateFromCallKit()
      }
  }
  ```
- Neither is known to the controller, for example because an adapter without an audio session
  handler forwards the system's activation to the engine itself: the controller resumes the
  engine and leaves the session to its owner.

When iOS resets its media services, the controller applies the category from
`configureForVoIP(allowBluetooth:defaultToSpeaker:)` again, activates the session again if
`activate()` had activated it, and restarts the engine's audio with
``BaresipEngine/audioRouteDidChange()``.

### Early media

To hear a caller during an early media preview, before the user answers, activate the session
yourself: CallKit only activates it after the answer.

```swift
try await audio.activate()
try await engine.sendProgress(callID: incoming.id, earlyVideo: true)
```

A video-only preview, such as a door station's picture shown before ringing, needs no audio
session: pass `earlyAudio: false` and the audio stream stays inactive.

```swift
try await engine.sendProgress(callID: incoming.id, earlyVideo: true, earlyAudio: false)
```

A preview only receives, so without ICE a media relay that learns your address from your first
packet, such as rtpengine, never forwards the caller's media. Set
``BaresipNATConfiguration/pinhole`` on the account, or use ICE: empty RTP packets are then
sent until the caller's media arrives. ``BaresipNATConfiguration/rtcpMultiplexing``, on by
default, keeps RTP and RTCP on one port, so one NAT binding serves both.

### Choosing the audio output

The controller lists the outputs the user can choose, such as the earpiece, the loudspeaker,
wired headphones, Bluetooth or car audio, and routes call audio to one of them:

```swift
for output in audio.availableOutputs {
    print(output.name, output.route)
}
if let speaker = audio.availableOutputs.first(where: { $0.route == .speaker }) {
    try audio.selectOutput(speaker)
}
```

`currentOutput` is the output in use. Call the list again after the route change callback,
because outputs appear and go away while a call runs.

### Music on hold

A held call sends nothing unless the engine has music on hold. Many PBXs pass a phone's hold
through to the other side instead of playing their own music, so the phone plays it from a
WAV file:

```swift
var configuration = BaresipConfiguration(instanceUUID: installID)
configuration.audio.holdMusicFile = Bundle.main.url(forResource: "HoldMusic", withExtension: "wav")
```

The file is a 16-bit PCM WAV file, mono or stereo, 8 to 48 kHz; the engine reads it when it is
created and throws if it cannot. While ``BaresipEngine/hold(callID:)`` holds a call, the tune
replaces the microphone and plays in a loop, resampled to the call's codec. It needs no audio
session, so it keeps playing when iOS deactivates the session of a call that is only on hold.
On resume the microphone comes back.

### Voice processing

Echo cancellation, noise suppression and gain control come from the VoiceProcessingIO audio
unit, which the engine always uses on iOS.
