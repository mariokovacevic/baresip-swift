# Limitations and planned work

| Area | Status | Plan |
|---|---|---|
| ICE restart with Asterisk | Asterisk 23 regenerates its credentials on a restart offer but keeps its old ICE session when the candidates are unchanged, so an explicit `restartICE` without a network change loses media with Asterisk; restarts after an address change work | report upstream to Asterisk |
| Trickle ICE | not supported (full candidate exchange in SDP) | none planned |
| Video bitrate adaptation | fixed target bitrate with a token-bucket pacer; no REMB/TWCC | facade-side reaction to RTCP loss reports |
| External audio injection | not exposed in ABI 0.1 | `ausrc`/`auplay` style callbacks in a later ABI revision |
| G.722 | not in the default module set (needs spandsp or libg722) | add on request |
| ZRTP | needs libzrtpcpp; capability check only | none planned |
| Software AEC | not needed on iOS (VoiceProcessingIO); `webrtc_aec` module needs an external library | none planned |
| Zero-copy decoded frames | the decoder's `CVPixelBuffer` is copied into the frame sink's buffer because baresip's `vidframe` has no native-buffer slot | small baresip extension or a side channel from `vidtoolbox` to the sink |
| Camera on the simulator | no camera; use `fakevideo`. `bskcapture` is compiled in CI but only exercised on a physical device | manual device test |
| CallKit / PushKit end to end | adapters compile and the sample app builds in CI; reporting a call to CallKit and receiving VoIP pushes need a signed app on a device and a VoIP certificate | manual device test |
| Intel simulators | the XCFramework ships an arm64 simulator slice only | build with `SLICES` including `ios-x86_64-simulator` |

Applied upstream patches (all in `Patches/`, to be proposed upstream): Contact URI parameters API, avcapture CMake gate and iOS guards, libre server-verification handler, ICE module events, starting media after ICE connects with optional SRTP.
