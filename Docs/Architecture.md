# Architecture

```
 App (SwiftUI / UIKit)
   │
   ├── BaresipKitCallKit   BaresipKitPushKit   BaresipKitAudio   BaresipKitVideo   (Layer 5, optional)
   │
   └── BaresipKit          idiomatic Swift API: BaresipEngine, AsyncStream<BaresipEvent>   (Layer 4)
         │
         ├── BaresipKitBridge   C helpers for the event union, module map                    (Layer 3)
         │
         └── BaresipKitCore     C ABI: baresip_kit.h, Core/src/*.c                            (Layer 2)
               │
               └── baresip + libre (+librem) + OpenSSL + Opus [+ libvpx]                     (Layer 1)
                   VideoToolbox H.264 (Core/src/apple/vidtoolbox.c), camera (bskcapture.m)
```

## Layer 1: the C core

Built from pinned upstream sources by `Build/build-xcframework.sh` with the patches in `Patches/` applied. baresip modules are linked statically (`STATIC=ON`); the set is chosen at build time (`Build/module-sets.env`). On Apple platforms the facade also registers two BaresipKit-owned modules that upstream baresip does not have: the `vidtoolbox` H.264 codec and the `bskcapture` camera source.

## Layer 2: BaresipKitCore

`Core/include/baresip_kit.h` is the only header a binding sees. It contains no libre or baresip types. The implementation in `Core/src`:

| File | Responsibility |
|---|---|
| `bsk_engine.c` | engine thread running libre's `re_main`, synchronous call marshalling through an `mqueue`, start/stop, lifecycle hooks (push wake-up, suspend/resume, network change, audio session) |
| `bsk_account.c` | accounts, registration state machine, Contact URI parameters with in-place updates |
| `bsk_call.c` | calls, the 14-state call machine, DTMF sequences, hold/resume, mute, media direction, transfer, statistics, ICE events |
| `bsk_video.c` | frame sinks (remote via a `vidisp`, local via a `vidfilt` tap), camera preview, device list |
| `bsk_tls.c` | SPKI SHA-256 pinning on top of the libre verify handler (patch 0004) |
| `bsk_log.c` | log routing with redaction of Digest responses, push tokens and passwords, SIP trace routing |

Threading and ownership rules are in [C-ABI.md](C-ABI.md). In one sentence: every `bsk_*` call is thread-safe and executes on the engine thread; events arrive on the engine thread; video frames arrive on media threads.

## Layer 3: BaresipKitBridge

Static inline C helpers that copy union members of `bsk_event` into plain structs so Swift never touches the union, plus the module map.

## Layer 4: BaresipKit

`BaresipEngine` wraps the opaque engine handle. Calls are `async` and run on a private queue because the C calls block until the engine thread has executed them. Events are delivered through `AsyncStream<BaresipEvent>`; every subscriber gets every event. All public types are `Sendable`.

## Layer 5: adapters

- `BaresipKitAudio`: `BaresipAudioSessionController` forwards activation, route changes and interruptions to the engine; it never configures the session unless `configureForVoIP()` is called explicitly.
- `BaresipKitCallKit`: `BaresipCallKitAdapter` maps call IDs to UUIDs, drives `CXProvider`, handles answer-before-INVITE after a push, and forwards audio activation.
- `BaresipKitPushKit`: `BaresipPushKitAdapter` collects the VoIP token, builds the Contact parameters and triggers the push wake-up.
- `BaresipKitVideo`: `BaresipVideoView` renders frames with `AVSampleBufferDisplayLayer`; `BaresipVideoFrameRelay` forwards frames to closures.

## What the core never does

It never owns `AVAudioSession`, never sends APNs or FCM traffic, never accepts a TLS certificate without verification unless `verify_server` is explicitly disabled, and never logs credentials or complete push tokens.
