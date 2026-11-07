# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-11-07

First public release.

### Added

- SIP registration over UDP, TCP and TLS, with private CAs, mutual TLS and SPKI pinning, and
  push `Contact` parameters (RFC 8599 style) updated in place.
- Audio calls with Opus and G.711, and H.264 video calls through VideoToolbox with zero-copy
  decoded frames; VP8 in the `full` module set.
- Hold, resume, mute, DTMF over RFC 4733 and SIP INFO, several calls with switching, blind and
  attended transfer (REFER with Replaces), and following incoming transfers.
- SIP MESSAGE (RFC 3428) sending and receiving, early media preview of incoming calls, call
  recording to stereo WAV, and media statistics with a MOS estimate.
- SRTP (SDES) and DTLS-SRTP; ICE with STUN and TURN over UDP, TCP and TLS; ICE restart on
  network changes; adaptive video bitrate from RTCP loss.
- `BaresipKitAudio`, `BaresipKitVideo`, `BaresipKitCallKit` and `BaresipKitPushKit` adapters,
  and a SwiftUI sample app with a UI test that runs in CI.
- DocC documentation for every public symbol, with Getting Started, Audio Session, Video,
  CallKit, PushKit and Push Contact Parameters articles.
- Swift 6 language mode with strict concurrency; Swift and C sources build without warnings.
- Lint and format scripts, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, and issue and pull request
  templates.

### Deprecated

- `ContactParameter`, `TURNServer` and the engine-level `resume()`: use
  `BaresipContactParameter`, `BaresipTURNServer` and `resumeFromBackground()`.

[Unreleased]: https://github.com/mariokovacevic/baresip-swift/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/mariokovacevic/baresip-swift/releases/tag/v1.0.0
