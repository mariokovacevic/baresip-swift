# Video

Show remote and local video, switch cameras and control the bitrate.

## Overview

H.264 is encoded and decoded by VideoToolbox. Decoded frames and frames straight from the
camera reach a ``BaresipVideoRenderer`` as the original `CVPixelBuffer`, without a copy, on a
media thread. A frame with no native buffer, such as a camera frame the engine converted for the
encoder (the local preview while the camera is sent in a call), is copied into an
IOSurface-backed buffer, with I420 copied as NV12, so the renderer still shows a picture instead
of nothing.

Every call negotiates video, so the other side's picture is received in audio calls too,
including early media while a call rings, such as a door station's camera. The `video` argument
of `makeCall` and `answer`, and `setVideoEnabled(_:callID:)`, only decide whether your camera
is sent. Show the remote view while ``BaresipCallInfo/videoDirection`` is `.receiveOnly` or
`.sendReceive`.

`BaresipVideoView` from the `BaresipKitVideo` module displays frames through an
`AVSampleBufferDisplayLayer`:

```swift
import BaresipKitVideo

let remote = BaresipVideoView()
try await engine.setVideoRenderer(remote.renderer, callID: call)

let local = BaresipVideoView()
try await engine.setVideoRenderer(local.renderer, callID: call, local: true)
```

In SwiftUI, `BaresipCallVideo` attaches a view to a call and detaches it when the view goes away:

```swift
BaresipCallVideo(engine: engine, callID: call)
BaresipCallVideo(engine: engine, callID: call, source: .local, mirrored: true)
    .frame(width: 100, height: 140)
```

With `BaresipKitSwiftUI`, `BaresipCallVideo(call:source:)` and `BaresipSelfView` take a
`BaresipPhoneCall` and mirror the front camera on their own; see <doc:SwiftUI>.

To process frames yourself, implement ``BaresipVideoRenderer`` or use
`BaresipVideoFrameRelay` with closures. Retain a frame's pixel buffer if you keep it after the
callback returns.

### Cameras and preview

```swift
let cameras = await engine.videoDevices()
try await engine.startVideoPreview(device: cameras.first, renderer: local.renderer)
try await engine.setCamera(.back, callID: call)
try await engine.setVideoEnabled(false, callID: call)
```

### Snapshots

`BaresipKitVideo` draws a frame into an upright `CGImage`, for example to keep a door station's
picture with the call history or to show it in a notification:

```swift
let image = videoView.snapshot()            // the frame on screen
let image = frame.makeImage()               // any frame from a renderer
```

### Picture updates

When received video is damaged or starts without a key frame, the engine asks the peer for a new
picture with RTCP PLI or FIR. Endpoints that react only to SIP INFO (RFC 5168) get the request
that way too with ``BaresipAccountConfiguration/pictureUpdateOverSIPInfo``. Incoming SIP INFO
picture update requests are always answered with a key frame.

### Bitrate

With ``BaresipConfiguration/videoAdaptiveBitrate``, the encoder target follows packet loss
reported by RTCP, between ``BaresipConfiguration/videoMinimumBitrate`` and
``BaresipVideoConfiguration/bitrate``. ``BaresipEngine/setVideoMaxBitrate(_:callID:)``
caps a single call, for example on a cellular link, and
``BaresipCallStatistics/videoTargetBitrate`` reports the current target.
