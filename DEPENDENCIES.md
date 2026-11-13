# Dependencies

All third-party code is built from pinned source by `Build/build-xcframework.sh`; nothing is downloaded as a prebuilt binary. Pins: `Build/versions.env`.

| Component | Version | License | Role | Notes |
|---|---|---|---|---|
| libre | v4.13.0 | BSD-3-Clause | SIP, SDP, RTP/RTCP, ICE/STUN/TURN, SRTP, TLS wrapper, main loop; includes librem (audio/video helpers) | one patch in `Patches/` |
| baresip | v4.13.0 | BSD-3-Clause | user agent, calls, media pipeline, modules | patches in `Patches/`, each with its rationale |
| OpenSSL | 3.5.9 (LTS) | Apache-2.0 | TLS, DTLS-SRTP, crypto for SRTP and Digest | NOTICE must ship with the app |
| Opus | 1.6.1 | BSD-3-Clause | audio codec | the Opus BSD license includes a patent grant from the contributors; no royalty |
| libvpx | 1.15.2 (`d168454`) | BSD-3-Clause | VP8 codec, optional (`MODULE_SET=full`) | Google patent grant in `PATENTS`; also used by the host video tests |
| G.711 | in baresip | BSD-3-Clause | audio codec | ITU-T G.711 patents expired |
| H.264 | VideoToolbox (system) on Apple platforms, MediaCodec (system) on Android | Apple SDK, Android SDK | video codec, BaresipKit `vidtoolbox` and `mediacodec` modules | **patent-encumbered**: AVC/H.264 is licensed through the Via-LA (formerly MPEG LA) pool. Using the OS-provided encoder/decoder on iOS is covered by Apple's license for the platform's codec; on Android the codec is the device's own; no FFmpeg or x264 code is shipped |
| G.722 | sippy/libg722 `a2688d2`, vendored in `Core/third_party/g722` | BSD-2-Clause, CMU (unrestricted), public domain | audio codec, registered by `bsk_g722.c` | baresip's own `g722` module needs spandsp (LGPL) and is not used; ITU-T G.722 patents expired |

Apple frameworks linked by the XCFramework: AudioToolbox, AVFoundation, CoreAudio, CoreFoundation, CoreMedia, CoreVideo, Foundation, Security, SystemConfiguration, VideoToolbox, plus `libresolv` and `libz`. The same list is in `Package.swift` and in the module map written by `Build/build-xcframework.sh`.

On Android, `PLATFORM=android Build/build-xcframework.sh` builds the same components from the same pins with the NDK, for `arm64-v8a` and `x86_64`, and the `baresipkit` library carries them in `libbaresipkit.so`. The native code links the NDK's `libaaudio`, `libmediandk`, `liblog`, `libz` and `libm`. The Kotlin libraries depend on kotlinx-coroutines, AndroidX Lifecycle, Jetpack core-telecom (`baresipkit-telecom`) and Jetpack Compose (`baresipkit-compose`), all Apache-2.0, resolved by Gradle from Maven Central and Google's Maven repository.

BaresipKit itself is BSD-3-Clause (`LICENSE`).

## Development tools

These are needed only to work on BaresipKit, not to use it.

| Tool | Version | License | Used for |
|---|---|---|---|
| Xcode | 16 or later | Apple | building the package, the XCFramework and the sample app |
| CMake | 3.18 or later | BSD-3-Clause | building the C core |
| clang-format | 18.1.3 | Apache-2.0 with LLVM exception | formatting C sources (`Scripts/format.sh`) |
| SwiftFormat | latest | MIT | formatting Swift sources |
| SwiftLint | latest | MIT | linting Swift sources |
| XcodeGen | latest | MIT | generating the sample app project |
| Docker | any recent | Apache-2.0 | the Asterisk and coturn integration tests |
| `andrius/asterisk` image | 23.5.0 (`23.5.0_debian-trixie-1b724ca`, pinned by digest) | GPL-2.0 (Asterisk) | SIP server of the integration tests and of `Scripts/dev-pbx.sh` |
| `coturn/coturn` image | 4.6.3 | BSD-3-Clause | TURN server of the integration tests and of `Scripts/dev-pbx.sh` |
| GitHub Actions | `actions/checkout` 4.4.0, `actions/cache` 4.3.0, `actions/upload-artifact` 4.6.2, pinned by commit | MIT | CI and the release workflow |

