# Limitations and planned work

| Area | Status | Plan |
|---|---|---|
| ICE restart with Asterisk | Asterisk 23 regenerates its credentials on a restart offer but keeps its old ICE session when the candidates are unchanged, so an explicit `restartICE` without a network change loses media with Asterisk; restarts after an address change work | report upstream to Asterisk |
| TURN over TCP or TLS lost during a call | The connection to the TURN server is not opened again by itself: the call reports the ICE state `failed` and media stops until `restartICE` is called, which connects, allocates and gathers again. The first connection, the TLS handshake and the allocation must finish within 10 seconds, or the call attempt fails | reconnect automatically if applications need it |
| ICE restart that fails | A restart that cannot gather candidates (for example the TURN server cannot be reached on the new network), or whose re-INVITE is not answered with new ICE credentials within 15 seconds, reports the ICE state `failed` and keeps the call. No re-INVITE is sent in the first case, so the peer keeps the old addresses until `restartICE` succeeds; call it again or hang up. The STUN/TURN server address resolved at the start of the call is reused and not resolved again, so a server that has another address on the new network is not found | resolve the server again when a deployment needs it |
| Call recording | WAV only, 16-bit; a direction whose sample rate differs from the other (rare, asymmetric codecs) is recorded as silence; video is not recorded | compressed formats on request |
| Trickle ICE | not supported (full candidate exchange in SDP) | none planned |
| Video bitrate adaptation | loss-based only: the encoder target follows RTCP receiver reports (cut on more than 10 % loss, slow increase below 2 %); no REMB/TWCC bandwidth estimation, so congestion without loss is not detected. With VP8 every change re-creates the encoder context (H.264 via VideoToolbox changes in place) | delay-based estimation if needed |
| External audio injection | not exposed in ABI 0.1 | `ausrc`/`auplay` style callbacks in a later ABI revision |
| SIP session timers (RFC 4028) | not supported by libre or baresip: no `Session-Expires` refresh. Calls work unless a proxy requires `timer` | add if a server requires it |
| RTCP-XR (RFC 3611) | not sent | none planned |
| ZRTP | needs libzrtpcpp; capability check only | none planned |
| Software AEC | not needed on iOS (VoiceProcessingIO); `webrtc_aec` module needs an external library | none planned |
| Zero-copy frames | H.264 frames decoded by VideoToolbox and camera frames reach the sink as the original `CVPixelBuffer`; VP8 frames, frames changed by a video filter and frames from other sources are copied into a new buffer | none planned |
| Camera on the simulator | no camera; use `fakevideo`. `bskcapture` is compiled in CI but only exercised on a physical device | manual device test |
| CallKit / PushKit end to end | adapters compile and the sample app builds in CI; reporting a call to CallKit and receiving VoIP pushes need a signed app on a device and a VoIP certificate | manual device test |
| Intel simulators | the XCFramework ships an arm64 simulator slice only | build with `SLICES` including `ios-x86_64-simulator` |

macOS: the XCFramework has an Apple silicon slice (`macos-arm64`, macOS 13 or later); there is no Intel slice yet. Audio goes through baresip's `audiounit` module, which uses the HAL output unit on macOS, so there is no echo cancellation; use headphones. `BaresipAudioSessionController`, the CallKit and PushKit adapters and `BaresipVideoView` are iOS only; on macOS, render frames from `BaresipVideoFrameRelay`. CI builds the package for macOS and runs the XCTest suite there, but no real call has been made on a Mac.

Applied upstream patches (all in `Patches/`, to be proposed upstream): Contact URI parameters API, avcapture CMake gate and iOS guards, libre server-verification handler, ICE module events, starting media after ICE connects with optional SRTP, TURN over TCP/TLS, ICE restart, video bitrate, video filter directions, NAT pinhole for receive-only audio, picture updates over SIP INFO, avcapture for iOS 16.
