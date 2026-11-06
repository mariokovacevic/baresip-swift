# BaresipKit iOS feasibility report (Phase 0)

Date: 2026-11-06. Status: **for review**. Nothing in Layers 3–5 (Swift API, adapters, sample app) has been started, as required.

## 1. Pinned versions

| Component | Tag | Commit | Notes |
|---|---|---|---|
| libre | `v4.9.0` | `e11a4c584bdb0cb30dde9d4f3e8a7a5717506855` | newest release at pin time |
| baresip | `v4.9.0` | `c06e3678cab6e7b5cfb504101cb82f862f2efb15` | newest release at pin time |
| librem | — | — | **merged into libre** (`re/rem/`, CMake option `USE_REM=ON`); the separate `rem` repository stopped at v2.9.0 and is not needed |
| OpenSSL | `openssl-3.5.9` | `45e844fa2a14ec92d146bd8f5778ac130b6625fb` | 3.5 is the current LTS line (supported until April 2030); 3.6.x is also available but not LTS |
| Opus | `v1.6.1` | `22244de5a79bd1d6d623c32e72bf1954b56235be` | |
| libvpx (optional, VP8) | `v1.15.2` | to pin when `MODULE_SET=full` is first built | |

The pins live in `Build/versions.env`; the build script refuses to build if the checked-out commit differs.

The legacy `baresip/baresip-ios` repository (`3d16b82`) was reviewed: it is a `Makefile` + `mk/contrib.mk` that clones unpinned `re`, `rem`, `baresip` master and produces lipo fat archives. It was used only to confirm the framework list (AudioToolbox, AVFoundation, CoreMedia, CoreVideo, Foundation) and is not reused.

## 2. Deployment target and toolchain

- iOS 17.0 minimum (`IOS_DEPLOYMENT_TARGET=17.0` in `Build/versions.env`, `-mios-version-min=17.0` / `-mios-simulator-version-min=17.0` for OpenSSL, `CMAKE_OSX_DEPLOYMENT_TARGET` for CMake projects).
- Xcode: the script uses whatever `xcrun` resolves; it was written against the Xcode 16/17 SDK layout (`iphoneos`, `iphonesimulator`). The exact Xcode version is one of the inputs still to be confirmed (see §9).
- CMake ≥ 3.18 (baresip's minimum), native `CMAKE_SYSTEM_NAME=iOS` support (no third-party toolchain file needed; `Build/cmake/ios.toolchain.cmake` only pins SDK, arch, deployment target and disables C11 `threads.h` detection, which libre would otherwise probe).

## 3. Build proof

### What was verified here (Linux x86_64 container, no Xcode available)

| Step | Result |
|---|---|
| libre v4.9.0 static via CMake (`LIBRE_BUILD_SHARED=OFF`, BFCP/RTMP/PCP off) | builds, `libre.a` 1.5 MB unstripped, text+data 602 KB |
| Opus v1.6.1 static via CMake | builds, `libopus.a` 1.0 MB, text+data 590 KB |
| baresip v4.9.0 + `Patches/0001` + `0002`, `STATIC=ON`, 20 modules (`account g711 opus l16 auconv auresamp ausine aufile ice turn stun srtp dtls_srtp netroam uuid contact mwi presence rtcpsummary debug_cmd`) | builds, module objects folded into `libbaresip.a` (935 KB, text+data 361 KB), generated `static.c` export table |
| Contact parameter proof, libre level | PASS (see `ContactParameterProof.md`) |
| Contact parameter proof, baresip level through the patched API | PASS |
| `Build/build-xcframework.sh` in `PLATFORM=host` mode (clones pinned sources, verifies commits, applies patches, builds OpenSSL 3.5.9 from source, Opus, libre, baresip, merges one archive) | see §3.3 |
| Proposed ABI header compiles as C11 and C++17 with `-Wall -Wextra -pedantic` | PASS |

### What could **not** be verified here

The iOS device arm64 and simulator arm64 slices, the `xcodebuild -create-xcframework` step and the real arm64 binary sizes require macOS with Xcode. This container is Linux. The script encodes the exact invocations (OpenSSL targets `ios64-xcrun` and `iossimulator-arm64-xcrun`, CMake with `CMAKE_SYSTEM_NAME=iOS`, `libtool -static`, `xcodebuild -create-xcframework`, `swift package compute-checksum`) and everything up to the Apple-specific tools was executed on the host path. **The first action on a Mac is `Build/build-xcframework.sh` and the numbers in §5 must be replaced by its `sizes.txt` output.** This is the main open risk of the phase and is listed in §9.

### 3.3 Host run of the build script

`PLATFORM=host MODULE_SET=minimal Build/build-xcframework.sh` on the Linux container (x86_64, GCC 13):

- pins verified against `Build/versions.env`, both patches applied cleanly with `git apply --3way`;
- OpenSSL 3.5.9 configured with the option set from §4 and built from source;
- Opus 1.6.1, libre 4.9.0 and baresip 4.9.0 (13 modules of the `minimal` set, `audiounit` skipped on non-Apple hosts) built and installed into the slice prefix;
- the five archives merged into one `libBaresipKitCore.a` (GNU `ar` MRI script on Linux, `libtool -static` on macOS), `Headers/` populated with `baresip_kit.h` and `module.modulemap`;
- the baresip-level Contact proof program links against the merged archive alone plus `-lz -lresolv -lpthread -lm -ldl`, which confirms the archive is self-contained including static OpenSSL.

Two script bugs were found and fixed by this run (bash `local` evaluation order, duplicate object names when merging with GNU `ar`). The Apple-only steps (`libtool`, `xcodebuild`, `swift package compute-checksum`) are the only parts not exercised.

## 4. TLS backend

- libre's default and only fully featured backend is OpenSSL (`re/cmake/re-config.cmake:19-23`; mbedTLS is an option but DTLS-SRTP, `tls_set_srtp`, fingerprints and SNI code paths are OpenSSL). Apple's Security framework is not a libre backend; without OpenSSL libre falls back to stubs with no TLS at all (`CMakeLists.txt:522-543`).
- OpenSSL 3.5.9 is built from the pinned tag with: `no-shared no-dso no-engine no-module no-apps no-tests no-docs no-legacy no-comp no-ssl3 no-weak-ssl-ciphers no-ui-console no-async`. These options keep the provider model (needed by libre 4.x) but drop the legacy provider, compression and the apps.
- License: Apache License 2.0 (OpenSSL 3.x). Obligations: ship the license text and the NOTICE, no advertising clause. Recorded in `THIRD_PARTY_NOTICES.md`.
- Export/App Store: the app that embeds the XCFramework must answer the encryption export question; standard TLS/SRTP qualifies for the exemption but the app owner files the declaration.
- Binary size impact: OpenSSL is the largest component (see §5). A future size reduction is possible with additional `no-*` options (e.g. `no-ec2m no-sm2 no-sm3 no-sm4 no-md4 no-mdc2 no-rc2 no-rc4 no-rc5 no-whirlpool no-camellia no-cast no-idea no-seed no-bf no-dsa no-srp no-psk no-ocsp no-ts no-cms no-ct`) once the required cipher suites are confirmed.

## 5. Binary size

Measured on the Linux x86_64 host from the build-script run (Release, unstripped static archives; `size -t` text+data is the better proxy for what ends up in an app after dead-stripping):

| Archive (`MODULE_SET=minimal`, host) | archive bytes | text+data bytes |
|---|---|---|
| `libre.a` | 1,521,484 | 610,928 |
| `libbaresip.a` (13 modules incl. SRTP, DTLS-SRTP, ICE, TURN) | 834,442 | 329,874 |
| `libopus.a` | 1,021,660 | 589,554 |
| `libssl.a` (OpenSSL 3.5.9, options from §4) | 2,119,428 | 924,179 |
| `libcrypto.a` (OpenSSL 3.5.9, options from §4) | 12,177,496 | 5,444,282 |
| merged `libBaresipKitCore.a` | 17,674,038 | 7,767,781 |
| proof executable linked fully static against the merged archive (upper bound, no `-ffunction-sections`/`--gc-sections`) | 8,856,856 (7,871,672 stripped) | — |

For comparison, a 20-module baresip built by hand (adds netroam, contact, mwi, presence, ausine, aufile, debug_cmd) is 936,018 bytes / 360,762 text+data, so the module set moves the baresip part by tens of kilobytes; OpenSSL's `libcrypto` is the component that decides the final size (about 70 % of the code). x86_64 `libcrypto` carries large assembly implementations; arm64 is typically 20–30 % smaller, and the dead-stripping linker removes everything the SIP stack never references (most of `libcrypto`'s PEM/X.509 tooling stays, most ciphers go). Expected arm64 per-slice archive: 12–15 MB; expected app download size impact after linking and stripping: 3–5 MB without VP8. These remain estimates until the macOS run; `Build/out/sizes.txt` records the real values. Reducing `libcrypto` further with additional `no-<algorithm>` options is the first size lever once the required cipher suites are confirmed.

## 6. CMake build and XCFramework

`Build/build-xcframework.sh`:

1. Sources `Build/versions.env` and `Build/module-sets.env`.
2. Clones each pinned tag with `--depth 1`, checks `HEAD` against the pinned commit, records `pins.txt`.
3. Applies `Patches/*-<project>-*.patch` with `git apply --3way` (verified on the host run: both patches apply cleanly).
4. Per slice (`ios-arm64`, `ios-arm64-simulator`, optionally `ios-x86_64-simulator`): OpenSSL (`Configure <target>`), Opus (CMake), libvpx (configure, only for `full`), libre (CMake, `USE_OPENSSL=ON`), baresip (CMake, `STATIC=ON`, `MODULES=<set>`).
5. Merges the per-slice archives into `libBaresipKitCore.a` with `libtool -static` (never `lipo`; device arm64 and simulator arm64 are separate slices).
6. `xcodebuild -create-xcframework` with one `-library/-headers` pair per slice; headers are `baresip_kit.h` + `module.modulemap` only, so libre/baresip headers never reach the Swift package.
7. Zips and computes the SPM checksum.

Module sets are selected at build time (`MODULE_SET=minimal|default|full`), which is how binary size is controlled. `PLATFORM=host` builds the same tree natively for CI (sanitizers via `SANITIZE=address,undefined`).

Two build details found during this phase:

- `modules/avcapture` is skipped for `CMAKE_SYSTEM_NAME=iOS` without `Patches/0002`.
- libre's installed CMake package does not export its compile definitions; `HAVE_UNIXSOCK` changes `sizeof(struct sa)`. The script keeps libre's defaults so facade and library agree, and the facade is compiled inside the same tree. (A two-line upstream change to export the definition is a candidate patch.)

## 7. Feature compatibility matrix

See `CompatibilityMatrix.md`. Headline results:

- Supported as-is or by existing modules: SIP over UDP/TCP/TLS/WSS, Digest MD5 and SHA-256, RFC 5626 outbound, multiple accounts and calls, hold/resume with correct SDP directions and remote-hold events, early media incl. early video, REFER (blind and attended), DTMF RFC 4733 and SIP INFO with per-call selection, ICE/STUN/TURN-UDP, SRTP (SDES, AES-CM and AES-GCM) and DTLS-SRTP, TLS 1.2+ with hostname verification, private CA from memory, Opus/G.711, VoiceProcessingIO audio with hardware AEC/NS/AGC, RTCP NACK/PLI/FIR, call statistics.
- Needs a small patch (written and verified): Contact URI parameters for push; avcapture CMake gate.
- Needs facade code: typed state machines, DTMF sequences, network-change entry point, audio session activation hooks, MOS estimate, log redaction, VideoToolbox H.264 codec module, AVFoundation capture with `CVPixelBuffer` pass-through, frame sink.
- Needs a later patch: certificate pinning hook (libre), TURN over TCP/TLS inside ICE, ICE restart.
- Not supported by baresip: trickle ICE, REMB/TWCC bitrate adaptation, software AEC without the external WebRTC library, ZRTP without libzrtpcpp.

## 8. Contact parameter proof

See `ContactParameterProof.md`. PASS at both the libre level and through the patched baresip API, with traces in this directory.

## 9. Open items and inputs still needed

1. **Build on macOS** to produce the real XCFramework and arm64 sizes (blocked here by the Linux container).
2. Confirm Xcode version and that iOS 17.0 is final.
3. Confirm SPM binary target as the distribution channel (assumed yes; the script already produces the zip + checksum).
4. Codec list: assumed Opus + G.711 + H.264; G.722 (needs spandsp or libg722) and VP8 are optional.
5. Reference REGISTER packet and reference SDP offer/answer from the target deployment, to turn `verify_trace.py` into the "compare against reference packet" helper requested in §3 of the brief.
6. SIP server transports/ports and a test endpoint for interop (not needed until Phase 1 integration tests).
7. Decision on the three "later patch" items (pinning hook, TURN-TCP/TLS in ICE, ICE restart) versus documenting them as limitations for the first release.

## 10. Proposed C ABI

See `C-ABI.md` and `Sources/BaresipKitCore/include/baresip_kit.h`.
