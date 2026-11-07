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

The controller forwards route changes and interruptions to the engine with
``BaresipEngine/audioRouteDidChange()`` and ``BaresipEngine/audioInterruption(began:)``.

### Early media

To hear a caller during an early media preview, before the user answers, activate the session
yourself: CallKit only activates it after the answer.

```swift
try await audio.activate()
try await engine.sendProgress(callID: incoming.id, earlyVideo: true)
```

### Voice processing

Echo cancellation, noise suppression and gain control come from the VoiceProcessingIO audio
unit, enabled by ``BaresipAudioConfiguration/voiceProcessing``.
