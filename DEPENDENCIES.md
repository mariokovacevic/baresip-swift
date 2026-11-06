# Dependencies

All third-party code is built from pinned source by `Build/build-xcframework.sh`; nothing is downloaded as a prebuilt binary. Pins: `Build/versions.env`.

| Component | Version | License | Role | Notes |
|---|---|---|---|---|
| libre | v4.9.0 | BSD-3-Clause | SIP, SDP, RTP/RTCP, ICE/STUN/TURN, SRTP, TLS wrapper, main loop; includes librem (audio/video helpers) | |
| baresip | v4.9.0 | BSD-3-Clause | user agent, calls, media pipeline, modules | two small patches in `Patches/` |
| OpenSSL | 3.5.9 (LTS) | Apache-2.0 | TLS, DTLS-SRTP, crypto for SRTP and Digest | NOTICE must ship with the app |
| Opus | 1.6.1 | BSD-3-Clause | audio codec | the Opus BSD license includes a patent grant from the contributors; no royalty |
| libvpx | 1.15.2 (`d168454`) | BSD-3-Clause | VP8 codec, optional (`MODULE_SET=full`) | Google patent grant in `PATENTS`; also used by the host video tests |
| G.711 | in baresip | BSD-3-Clause | audio codec | ITU-T G.711 patents expired |
| H.264 | VideoToolbox (system) | Apple SDK | video codec, BaresipKit `vidtoolbox` module | **patent-encumbered**: AVC/H.264 is licensed through the Via-LA (formerly MPEG LA) pool. Using the OS-provided encoder/decoder on iOS is covered by Apple's license for the platform's codec; no FFmpeg or x264 code is shipped |
| G.722 | spandsp or libg722, optional | LGPL-2.1 / BSD | audio codec | not in the default set because of the LGPL option; libg722 (BSD) is the choice if G.722 is required |

Apple frameworks linked by the XCFramework: AudioToolbox, AVFoundation, CoreMedia, CoreVideo, Foundation, Security, VideoToolbox, plus `libresolv` and `libz`.

BaresipKit itself is BSD-3-Clause (`LICENSE`).
