# Video

Show remote and local video, switch cameras and control the bitrate.

## Overview

H.264 is encoded and decoded by VideoToolbox. Decoded frames and camera frames reach a
``BaresipVideoRenderer`` as the original `CVPixelBuffer`, without a copy, on a media thread.

`BaresipVideoView` from the `BaresipKitVideo` module displays frames through an
`AVSampleBufferDisplayLayer`:

```swift
import BaresipKitVideo

let remote = BaresipVideoView()
try await engine.setVideoRenderer(remote.renderer, callID: call)

let local = BaresipVideoView()
try await engine.setVideoRenderer(local.renderer, callID: call, local: true)
```

To process frames yourself, implement ``BaresipVideoRenderer`` or use
`BaresipVideoFrameRelay` with closures. Retain a frame's pixel buffer if you keep it after the
callback returns.

### Cameras and preview

```swift
let cameras = await engine.videoDevices()
try await engine.startVideoPreview(device: cameras.first, renderer: local.renderer)
try await engine.setCamera("back", callID: call)
try await engine.setVideoEnabled(false, callID: call)
```

### Bitrate

With ``BaresipConfiguration/videoAdaptiveBitrate``, the encoder target follows packet loss
reported by RTCP, between ``BaresipConfiguration/videoMinimumBitrate`` and
``BaresipVideoConfiguration/bitrate``. ``BaresipEngine/setVideoMaxBitrate(callID:bitsPerSecond:)``
caps a single call, for example on a cellular link, and
``BaresipCallStatistics/videoTargetBitrate`` reports the current target.
