# Architecture

```
 App (SwiftUI / UIKit)
   │
   ├── BaresipKitCallKit   BaresipKitLiveCommunication   BaresipKitPushKit   BaresipKitAudio
   │   BaresipKitVideo     BaresipKitSwiftUI                                                   (Layer 5, optional)
   │     └── BaresipKitSystemCall   call bookkeeping and push-to-INVITE matching shared by both call adapters (internal)
   │
   └── BaresipKit          idiomatic Swift API: BaresipEngine, AsyncStream<BaresipEvent>   (Layer 4)
         │
         ├── BaresipKitBridge   C helpers for the event union, module map                    (Layer 3)
         │
         └── BaresipKitCore     C ABI: baresip_kit.h, Core/src/*.c                            (Layer 2)
               │
               └── baresip + libre (+librem) + OpenSSL + Opus [+ libvpx]                     (Layer 1)
                   VideoToolbox H.264 (Core/src/apple/vidtoolbox.c, RTP depacketizer in
                   Core/src/bsk_h264.c), camera (bskcapture.m)
```

## Layer 1: the C core

Built from pinned upstream sources by `Build/build-xcframework.sh` with the patches in `Patches/` applied. baresip modules are linked statically (`STATIC=ON`); the set is chosen at build time (`Build/module-sets.env`). On Apple platforms the facade also registers two BaresipKit-owned modules that upstream baresip does not have: the `vidtoolbox` H.264 codec and the `bskcapture` camera source.

## Layer 2: BaresipKitCore

`Core/include/baresip_kit.h` is the only header a binding sees. It contains no libre or baresip types. The implementation in `Core/src`:

| File | Responsibility |
|---|---|
| `bsk_engine.c` | engine thread running libre's `re_main`, synchronous call marshalling through an `mqueue`, create, start, stop and destroy |
| `bsk_engine_control.c` | lifecycle hooks: push wake-up, suspend and resume, network change, audio session |
| `bsk_config.c` | copying the engine configuration and generating the baresip configuration and TLS setup |
| `bsk_status.c` | version, status strings, errors and the capability list |
| `bsk_account.c` | accounts, registration state machine, Contact URI parameters with in-place updates |
| `bsk_call.c` | the 14-state call machine, call events, incoming transfers, early media preview, ICE events, placing calls |
| `bsk_call_ops.c` | call operations: answer, reject, hang up, hold, active call, DTMF sequences, mute, media direction, camera, recording, transfers, info and statistics |
| `bsk_call_media.c` | ICE restart, the adaptive video bitrate loop and media statistics |
| `bsk_message.c` | SIP MESSAGE sending and receiving |
| `bsk_record.c` | call recording to stereo WAV |
| `bsk_rate.c` | the loss-based video bitrate controller |
| `bsk_video.c` | frame sinks (remote via a `vidisp`, local via a `vidfilt` tap), camera preview, device list |
| `bsk_tls.c` | SPKI SHA-256 pinning on top of the libre verify handler (patch 0004) |
| `bsk_log.c` | log routing with redaction of Digest responses, push tokens, passwords and SDES keys, SIP trace routing |
| `bsk_audio.c` | the `bskaudio` source and player that hold a call's audio until the audio session is active |
| `bsk_g722.c` | the G.722 codec, built on the vendored sippy/libg722 encoder and decoder in `Core/third_party/g722` |
| `bsk_h264.c` | H.264 RTP depacketization (single NAL, FU-A, STAP-A) into an Annex B access unit and its conversion to AVCC; used by the VideoToolbox decoder and tested on every platform |

### Design notes

- **Audio before the session is active.** baresip opens the audio device as soon as a stream starts, which can be on a 183 with early media or when SRTP is ready, before CallKit has activated the `AVAudioSession`. iOS then refuses to record and baresip ends the call. Every call therefore opens `bskaudio`: while the audio session is active it opens the configured device, otherwise it stays silent until `bsk_engine_audio_session_activated()` switches the call to the device.
- **Video is always negotiated.** Outgoing calls offer video and answers accept the caller's video, receive-only when the app does not send its camera (`bsk_call_video_dir`). Early media and the other side's picture, such as a door station's camera, are therefore shown in audio calls too.
- **Lasting media directions.** Once a call is up, baresip restores its "established" directions with a re-INVITE. For an incoming call these are the directions of the INVITE, sendrecv, which would turn the camera on after an answer without it. Answers, calls created by transfers and `bsk_call_set_audio_direction` therefore set the established directions together with the current ones (`bsk_call_set_lasting_dirs`).
- **Negotiated directions in call info.** `bsk_call_info` reports the directions from the negotiated SDP; until the peer's SDP has arrived nothing flows, so they are inactive.
- **G.722.** baresip's own `g722` module needs spandsp, which is LGPL. The core registers its own codec instead. Audio is sampled at 16 kHz, the RTP clock rate is 8 kHz for historical reasons (RFC 3551, section 4.5.2), and two samples become one octet.
- **Codec lists.** The engine's audio and video codec lists are the default for every account that sets no list of its own.
- **Incoming headers.** baresip keeps the headers named in an account's incoming header list for incoming calls; `bsk_call_get_header` reads them.
- **VideoToolbox sessions in the background.** iOS invalidates compression and decompression sessions while the app is in the background, and a decoder failure may only reach the output callback. A lost encoder session is dropped, so the next frame opens a new one and sends a key frame. A lost decoder session is reopened at the next key frame, and `EPROTO` makes baresip ask the peer for one.

Threading and ownership rules are in [C-ABI.md](C-ABI.md). In one sentence: every `bsk_*` call is thread-safe and executes on the engine thread; events arrive on the engine thread; video frames arrive on media threads.

## Layer 3: BaresipKitBridge

Static inline C helpers that copy union members of `bsk_event` into plain structs so Swift never touches the union, plus the module map.

## Layer 4: BaresipKit

`BaresipEngine` wraps the opaque engine handle. Calls are `async` and run on a private queue because the C calls block until the engine thread has executed them. Events are delivered through `AsyncStream<BaresipEvent>`; every subscriber gets every event. All public types are `Sendable`.

## Layer 5: adapters

- `BaresipKitAudio`: `BaresipAudioSessionController` forwards activation, route changes and interruptions to the engine; it never configures the session unless `configureForVoIP()` is called explicitly.
- `BaresipKitCallKit`: `BaresipCallKitAdapter` maps call IDs to UUIDs, drives `CXProvider`, handles answer-before-INVITE after a push, and forwards audio activation.
- `BaresipKitLiveCommunication`: `BaresipLiveCommunicationAdapter` does the same with LiveCommunicationKit's `ConversationManager` from iOS 17.4. Both adapters share `BaresipKitSystemCall`, an internal target with `SystemCallBook`, which holds the UUID of every call, pushed calls and their early answers and declines, and the outgoing calls being started, and the ledger that matches pushed calls to INVITEs. Each adapter keeps one `SystemCallBook` behind its lock and only talks to CallKit or LiveCommunicationKit itself.
- `BaresipKitPushKit`: `BaresipPushKitAdapter` collects the VoIP token, builds the Contact parameters and triggers the push wake-up.
- `BaresipKitVideo`: `BaresipVideoView` renders frames with `AVSampleBufferDisplayLayer`; `BaresipVideoFrameRelay` forwards frames to closures. From iOS 17 frames go straight to the layer's renderer, which accepts them from any thread; before iOS 17 they are handed to the main actor. A failed renderer shows nothing until it is flushed, and iOS asks for a flush after an interruption such as the app going to the background, so the view flushes it in both cases; otherwise the picture freezes while frames keep arriving.
- `BaresipKitSwiftUI`: `BaresipPhone` and `BaresipPhoneCall` apply the engine's events to published registration and call state for SwiftUI, and keep the active call. Actions go through a `BaresipCallController` such as the CallKit adapter for the calls it controls, and to the engine otherwise. `BaresipCallVideo` (in `BaresipKitVideo`) and `BaresipSelfView` show a call's video and your own camera.

## Android

```
 App (Compose / Views)
   │
   ├── baresipkit-telecom   baresipkit-push   baresipkit-audio   baresipkit-video
   │   baresipkit-compose                                                              (Layer 5, optional)
   │
   └── baresipkit          Kotlin API: BaresipEngine, SharedFlow<BaresipEvent>         (Layer 4)
         │
         ├── JNI bridge     Android/baresipkit/src/main/cpp, linked into libbaresipkit.so  (Layer 3)
         │
         └── BaresipKitCore the same C ABI and Core/src                                (Layer 2)
               │
               └── baresip + libre (+librem) + OpenSSL + Opus + libvpx, aaudio          (Layer 1)
                   MediaCodec H.264 (Core/src/android/mediacodec.c), camera source
                   (Core/src/android/bskcamera.c) fed from Camera2
```

Layers 1 and 2 are the same code as on Apple platforms, cross-compiled with the NDK by
`PLATFORM=android Build/build-xcframework.sh` with the same pins and patches. Only the platform
modules differ: `aaudio` instead of `audiounit`, `mediacodec` instead of `vidtoolbox`, and
`bskcamera` instead of `bskcapture`.

- **Layer 3, the JNI bridge**, is the counterpart of `BaresipKitBridge`: it turns `bsk_*` calls
  into native methods and each `bsk_event` into a Kotlin object, attaching the engine and media
  threads to the JVM as needed. It also builds for the Linux host, so the JVM unit tests run
  against the real core.
- **Layer 4, `baresipkit`**: `BaresipEngine` runs every C call on one dedicated thread through a
  coroutine dispatcher, so operations are `suspend` functions; events go to a `SharedFlow` that
  every collector receives in full. The type names follow the Swift API.
- **Layer 5, the adapters**: `BaresipTelecomAdapter` adds calls to Telecom through Jetpack
  core-telecom, with the same push-to-INVITE matching as the iOS call adapters;
  `BaresipPushAdapter` turns Firebase tokens into `Contact` parameters and reports pushed calls;
  `BaresipAudioController` holds audio focus and routes the output; `BaresipVideoView` renders
  frames with OpenGL ES and `BaresipCamera` feeds Camera2 frames to the core; `BaresipPhone` and
  `BaresipPhoneCall` are the Compose state holders.

The differences from iOS, and why, are listed in [Platforms.md](Platforms.md#parity-with-ios).

## What the core never does

It never owns `AVAudioSession` or Android's audio focus, never sends APNs or FCM traffic, never accepts a TLS certificate without verification (the C field `insecure_skip_verify` is rejected unless the core is built with `BARESIPKIT_ALLOW_INSECURE_TLS`, which no released binary is, and neither SDK can set it), never follows a transfer or answers a call on its own except for a REFER on an established call and an INVITE whose `Replaces` header names one, and never logs credentials or complete push tokens.
