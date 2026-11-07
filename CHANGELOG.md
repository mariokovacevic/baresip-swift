# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `BaresipMediaEvent.unknown` for media events from a newer core.
- DocC documentation for every public symbol, with Getting Started, Audio Session, Video,
  CallKit, PushKit and Push Contact Parameters articles.
- Lint and format scripts (`Scripts/lint.sh`, `Scripts/format.sh`) with SwiftFormat, SwiftLint
  and clang-format configuration; CI lint and DocC jobs.
- CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, issue and pull request templates.

### Changed

- `ContactParameter` is now `BaresipContactParameter`, `TURNServer` is `BaresipTURNServer`, and
  the engine-level `resume()` is `resumeFromBackground()`; the old names remain as deprecated
  aliases.
- The package uses the Swift 6 language mode with strict concurrency; Swift and C sources build
  without warnings.
- Call recording writes the file on the engine thread instead of the audio threads, and keeps
  both channels aligned when packets arrive in bursts.

### Removed

- `BaresipVideoSupport`, a placeholder string.

### Fixed

- `BaresipCallKitAdapter` could not be released because its event loop kept a strong reference.
- `reject(callID:statusCode:reason:)` trapped for status codes outside `UInt16`.
- `bsk_capabilities()` and `BaresipEngine.capabilities` reported implemented features as planned or unsupported.

## [0.1.0]

First version: SIP registration over UDP, TCP and TLS with private CAs, mutual TLS and SPKI
pinning; audio (Opus, G.711) and H.264 video calls through VideoToolbox; hold, mute, DTMF,
several calls, blind and attended transfer, SIP MESSAGE, early media preview, SRTP and
DTLS-SRTP, ICE with STUN and TURN over UDP, TCP and TLS, ICE restart, adaptive video bitrate,
call recording and statistics; CallKit and PushKit adapters; a sample app.

[Unreleased]: https://github.com/mariokovacevic/baresip-swift/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mariokovacevic/baresip-swift/releases/tag/v0.1.0
