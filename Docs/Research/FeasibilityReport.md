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
- Xcode: the script uses whatever `xcrun` resolves. Verified with Xcode 27.2 (27B52), iPhoneOS 27.2 and iPhoneSimulator 27.2 SDKs on macOS 27.0 (26A428), Apple silicon (see §3.4).
- bash: the script runs under the stock macOS `/bin/bash` 3.2; it no longer uses bash 4 builtins.
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

### What could not be verified in the Linux container

The iOS device arm64 and simulator arm64 slices, the `xcodebuild -create-xcframework` step and the real arm64 binary sizes require macOS with Xcode. They have since been run on a Mac; see §3.4. The numbers in §5 are the measured arm64 values from that run.

### 3.3 Host run of the build script

`PLATFORM=host MODULE_SET=minimal Build/build-xcframework.sh` on the Linux container (x86_64, GCC 13):

- pins verified against `Build/versions.env`, both patches applied cleanly with `git apply --3way`;
- OpenSSL 3.5.9 configured with the option set from §4 and built from source;
- Opus 1.6.1, libre 4.9.0 and baresip 4.9.0 (13 modules of the `minimal` set, `audiounit` skipped on non-Apple hosts) built and installed into the slice prefix;
- the five archives merged into one `libBaresipKitCore.a` (GNU `ar` MRI script on Linux, `libtool -static` on macOS), `Headers/` populated with `baresip_kit.h` and `module.modulemap`;
- the baresip-level Contact proof program links against the merged archive alone plus `-lz -lresolv -lpthread -lm -ldl`, which confirms the archive is self-contained including static OpenSSL.

Two script bugs were found and fixed by this run (bash `local` evaluation order, duplicate object names when merging with GNU `ar`). The Apple-only steps (`libtool`, `xcodebuild`, `swift package compute-checksum`) were not exercised there; they are covered by §3.4.

### 3.4 macOS run (iOS slices)

Environment: macOS 27.0 (26A428) on Apple silicon (arm64), Xcode 27.2 (27B52), `xcrun --sdk iphoneos --show-sdk-version` 27.2, `xcrun --sdk iphonesimulator --show-sdk-version` 27.2, CMake 3.28.1 (Homebrew), `/bin/bash` 3.2.57. Pins in `Build/versions.env` unchanged and verified by the script.

| Step | Result |
|---|---|
| `MODULE_SET=minimal Build/build-xcframework.sh` | PASS after the script fixes below: both slices, `libtool -static` merge, `xcodebuild -create-xcframework`, zip, `swift package compute-checksum` |
| `MODULE_SET=default Build/build-xcframework.sh` | PASS after adding `Patches/0003` (avcapture failed to compile: `'AVCaptureScreenInput' is unavailable: not available on iOS`, 3 errors at `avcapture.m:26`, `:216`, `:316`) |
| OpenSSL `Configure ios64-xcrun` / `iossimulator-arm64-xcrun` with `-mios-version-min=17.0` / `-mios-simulator-version-min=17.0` | builds unchanged; `mkinstallvars.pl` prints harmless "uninitialized value" warnings on stderr |
| libre with `CMAKE_SYSTEM_NAME=iOS` and `Build/cmake/ios.toolchain.cmake` | builds unchanged; resulting definitions include `DARWIN HAVE_KQUEUE HAVE_GETIFADDRS HAVE_UNIXSOCK=1 HAVE_ARC4RANDOM USE_OPENSSL USE_TLS USE_DTLS USE_ZLIB OS="iOS"`, no `HAVE_THREADS`, no `HAVE_RESOLV` |
| `audiounit` module | compiles for both slices (`audiounit.c.o`, `player.c.o`, `recorder.c.o` in `libbaresip.a`); its CMake gate accepts `iOS` already |
| Opus with `CMAKE_SYSTEM_NAME=iOS` | builds; prints `ERRORRuntime cpu capability detection needed for MAY_HAVE_NEON` (a `message(ERROR ...)` that CMake treats as a plain notice). Opus sets `OPUS_PRESUME_NEON` for iOS, NEON code is compiled in (10 `*_neon` functions in `libopus.a`), so no change was made |
| `xcrun lipo -info` on each slice | `ios-arm64`: arm64 only; `ios-arm64-simulator`: arm64 only (no fat archives) |
| `otool -l` over all 1,524 objects per slice | every object has `LC_BUILD_VERSION minos 17.0`; platform 2 (iOS) on the device slice, platform 7 (iOS Simulator) on the simulator slice. 22 OpenSSL assembly objects per slice report `sdk n/a`, the rest `sdk 27.2` |
| XCFramework `Info.plist` | `ios-arm64` (platform `ios`) and `ios-arm64-simulator` (platform `ios`, variant `simulator`), `Headers/` holds only `baresip_kit.h` and `module.modulemap` |
| `nm` | `_account_set_contact_params`, `_account_contact_params`, `_ua_set_contact_params` defined (`T`) in both slices (patch 0001 applied) |
| unresolved symbols | 272 (device) / 271 (simulator, no `___chkstk_darwin`) external undefined symbols, all from libSystem, libz (`_crc32`), libobjc and the AudioToolbox, AVFoundation, CoreMedia, CoreVideo, Foundation frameworks; none from libre, baresip, OpenSSL or Opus |
| `contact_proof_baresip.c` compiled with `xcrun -sdk iphonesimulator clang -arch arm64` (and `-sdk iphoneos` for the device slice) against the slice prefix headers and the merged archive only, plus `-framework AudioToolbox AVFoundation CoreMedia CoreVideo Foundation -lz -Wl,-dead_strip` | links without warnings for both slices and both module sets; executable has `platform IOSSIMULATOR minos 17.0` |
| simulator binary run with `xcrun simctl spawn booted` (iPhone 17, iOS 26.4) against `fake_registrar.py` on the Mac | PASS, `verify_trace.py ... A,A,B,B,B0`: initial REGISTER and auth retry with token set A, update to set B via `ua_set_contact_params`, timer refresh with B, unregister `expires=0`. Sanitized trace: `contact-parameter-trace-baresip-iossim.txt` |

Script fixes made by this run (`Build/build-xcframework.sh`):

1. `mapfile` is a bash 4 builtin and does not exist in macOS `/bin/bash` 3.2; the first run stopped at Opus with `Build/build-xcframework.sh: line 141: mapfile: command not found`. Replaced by a `while read` loop.
2. `apply_patches` reset the checkout with `git checkout -- .`, which restores from the index; `git apply --3way` stages the patched files, so reruns never returned to the pinned commit (they only worked because `--3way` tolerates already-applied hunks). Now `git reset --hard HEAD`.
3. `sizes.txt` wrote one "text+data" line per object member (it matched every `total` line of `size -m`). It now records, per module set and slice, bytes and text+data for the merged archive and each input library, plus the zip size and checksum. text+data is the sum of `__TEXT` and `__DATA` sections excluding zerofill (`__bss`, `__common`), the Mach-O equivalent of the Linux `size` figure.

A from-scratch run of the fixed script (`OUT_DIR=<repo>/Build/out/clean MODULE_SET=default`, all slices rebuilt) passed in 83 s wall time on 12 cores. A first from-scratch attempt with `OUT_DIR` under `/private/tmp` failed at libre's configure step (`OPENSSL_INCLUDE_DIR-NOTFOUND`, `Target "re" links to: OpenSSL::SSL but the target was not found`) although OpenSSL was installed in the prefix: `/tmp` is a symlink to `/private/tmp`, CMake used the `/tmp/...` spelling for the build tree, and with `CMAKE_FIND_ROOT_PATH_MODE_* ONLY` the prefix given as `/private/tmp/...` was not searched. `OUT_DIR` must therefore be a path without symlinks; the default `Build/out` is fine.

Test-harness note: the Mac used here has several interfaces, and baresip picked a Tailscale `utun` address (100.x) as its local address. Replies to that address are not delivered even host to host, so the run used a scratch copy of the proof with `net_interface en0` added to its config and `REGISTRAR_HOST` set to the en0 address. The program in the repository is unchanged.

## 4. TLS backend

- libre's default and only fully featured backend is OpenSSL (`re/cmake/re-config.cmake:19-23`; mbedTLS is an option but DTLS-SRTP, `tls_set_srtp`, fingerprints and SNI code paths are OpenSSL). Apple's Security framework is not a libre backend; without OpenSSL libre falls back to stubs with no TLS at all (`CMakeLists.txt:522-543`).
- OpenSSL 3.5.9 is built from the pinned tag with: `no-shared no-dso no-engine no-module no-apps no-tests no-docs no-legacy no-comp no-ssl3 no-weak-ssl-ciphers no-ui-console no-async`. These options keep the provider model (needed by libre 4.x) but drop the legacy provider, compression and the apps.
- License: Apache License 2.0 (OpenSSL 3.x). Obligations: ship the license text; OpenSSL 3 has no NOTICE file and no advertising clause. Recorded in `THIRD_PARTY_NOTICES.md`.
- Export/App Store: the app that embeds the XCFramework must answer the encryption export question; standard TLS/SRTP qualifies for the exemption but the app owner files the declaration.
- Binary size impact: OpenSSL is the largest component (see §5). A future size reduction is possible with additional `no-*` options (e.g. `no-ec2m no-sm2 no-sm3 no-sm4 no-md4 no-mdc2 no-rc2 no-rc4 no-rc5 no-whirlpool no-camellia no-cast no-idea no-seed no-bf no-dsa no-srp no-psk no-ocsp no-ts no-cms no-ct`) once the required cipher suites are confirmed.

## 5. Binary size

Measured on macOS from `Build/out/sizes.txt` (Xcode 27.2, Release, unstripped static archives). text+data is the sum of `__TEXT` and `__DATA` sections without zerofill, the best proxy for what reaches an app after dead-stripping.

### Per library, `ios-arm64` (device)

| Archive | archive bytes | text+data bytes | share of text+data (`default`) |
|---|---|---|---|
| `libcrypto.a` (OpenSSL 3.5.9, options from §4) | 8,559,752 | 4,008,326 | 68.5 % |
| `libssl.a` (OpenSSL 3.5.9) | 1,604,632 | 722,503 | 12.3 % |
| `libre.a` | 1,027,176 | 428,903 | 7.3 % |
| `libopus.a` | 650,408 | 412,378 | 7.0 % |
| `libbaresip.a`, `minimal` (14 modules) | 620,848 | 250,564 | — |
| `libbaresip.a`, `default` (22 modules) | 709,424 | 279,711 | 4.8 % |

### Merged `libBaresipKitCore.a` per slice and module set

| Module set | slice | archive bytes | text+data bytes |
|---|---|---|---|
| `minimal` | `ios-arm64` | 12,462,424 | 5,822,674 |
| `minimal` | `ios-arm64-simulator` | 12,502,992 | 5,869,545 |
| `default` | `ios-arm64` | 12,551,008 | 5,851,821 |
| `default` | `ios-arm64-simulator` | 12,591,432 | 5,898,696 |

The simulator slice differs mainly in `libopus.a` (681,872 / 450,718); `libbaresip.a`, `libre.a` and the OpenSSL archives differ by less than 7 KB each.

### XCFramework

| Module set | `BaresipKitCore.xcframework.zip` bytes | SPM checksum of that build |
|---|---|---|
| `minimal` | 9,471,120 | `7a53b435624bc5a6d21d9ead87d65fde82b5455eebc20160b6c5c442b7a96fb9` |
| `default` | 9,531,626 | `dc0d81ec5cc2da36e612925ac8d62d63e2947da4099ec3e4ddebf04a77dfacfd` |

Sizes also depend slightly on the absolute build path, which is embedded in OpenSSL and baresip (the clean run in `Build/out/clean` gave a `default` device archive of 12,553,112 bytes, 2 KB more). The checksum changes on every rebuild of identical sources (two `minimal` runs gave `b7a1ef5e…` and `7a53b435…`) because the archives and the zip carry timestamps. The release checksum must therefore come from the exact zip that is uploaded.

### Linked size (app impact proxy)

`contact_proof_baresip.c` linked against the merged archive with `-Wl,-dead_strip`, then `strip -x`:

| Module set | slice | linked bytes | stripped bytes | `__TEXT` | `__DATA` | stripped, `gzip -9` |
|---|---|---|---|---|---|---|
| `minimal` | `ios-arm64` | 5,585,976 | 5,281,688 | 4,292,608 | 49,152 | 2,655,365 |
| `default` | `ios-arm64` | 5,669,136 | 5,357,712 | 4,358,144 | 49,152 | 2,694,967 |

Against the Phase 0 estimates: the per-slice archive (12.5 MB) is inside the estimated 12–15 MB. The linked, stripped code is 5.3 MB, slightly above the estimated 3–5 MB uncompressed; compressed it is about 2.7 MB, which is closer to what an App Store download adds. The `default` set costs about 76 KB over `minimal` after linking. OpenSSL is 81 % of the archive's text+data, so the `no-<algorithm>` options listed in §4 remain the first size lever once the required cipher suites are confirmed. VP8 (`full`) and the `ios-x86_64-simulator` slice were not built.

## 6. CMake build and XCFramework

`Build/build-xcframework.sh`:

1. Sources `Build/versions.env` and `Build/module-sets.env`.
2. Clones each pinned tag with `--depth 1`, checks `HEAD` against the pinned commit, records `pins.txt`.
3. Resets each checkout to the pinned commit and applies `Patches/*-<project>-*.patch` with `git apply --3way` (all three baresip patches apply cleanly to the pinned tree).
4. Per slice (`ios-arm64`, `ios-arm64-simulator`, optionally `ios-x86_64-simulator`): OpenSSL (`Configure <target>`), Opus (CMake), libvpx (configure, only for `full`), libre (CMake, `USE_OPENSSL=ON`), baresip (CMake, `STATIC=ON`, `MODULES=<set>`).
5. Merges the per-slice archives into `libBaresipKitCore.a` with `libtool -static` (never `lipo`; device arm64 and simulator arm64 are separate slices).
6. `xcodebuild -create-xcframework` with one `-library/-headers` pair per slice; headers are `baresip_kit.h` + `module.modulemap` only, so libre/baresip headers never reach the Swift package.
7. Zips and computes the SPM checksum.

Module sets are selected at build time (`MODULE_SET=minimal|default|full`), which is how binary size is controlled. `PLATFORM=host` builds the same tree natively for CI (sanitizers via `SANITIZE=address,undefined`).

Two build details found during this phase:

- `modules/avcapture` is skipped for `CMAKE_SYSTEM_NAME=iOS` without `Patches/0002`, and does not compile against the iOS SDK without `Patches/0003` (macOS-only `AVCaptureScreenInput`).
- libre's installed CMake package does not export its compile definitions; `HAVE_UNIXSOCK` changes `sizeof(struct sa)`. The script keeps libre's defaults so facade and library agree, and the facade is compiled inside the same tree. On iOS libre is built with `HAVE_UNIXSOCK=1` (the Linux host proof used `0`), so any code compiled against libre headers must take the definitions from the slice build (`build/re/CMakeFiles/re-objs.dir/flags.make`), as the §3.4 link proof did. (A two-line upstream change to export the definition is a candidate patch.)

## 7. Feature compatibility matrix

See [`../CompatibilityMatrix.md`](../CompatibilityMatrix.md). Headline results:

- Supported as-is or by existing modules: SIP over UDP/TCP/TLS/WSS, Digest MD5 and SHA-256, RFC 5626 outbound, multiple accounts and calls, hold/resume with correct SDP directions and remote-hold events, early media incl. early video, REFER (blind and attended), DTMF RFC 4733 and SIP INFO with per-call selection, ICE/STUN/TURN-UDP, SRTP (SDES, AES-CM and AES-GCM) and DTLS-SRTP, TLS 1.2+ with hostname verification, private CA from memory, Opus/G.711, VoiceProcessingIO audio with hardware AEC/NS/AGC, RTCP NACK/PLI/FIR, call statistics.
- Needs a small patch (written and verified): Contact URI parameters for push; avcapture CMake gate.
- Needs facade code: typed state machines, DTMF sequences, network-change entry point, audio session activation hooks, MOS estimate, log redaction, VideoToolbox H.264 codec module, AVFoundation capture with `CVPixelBuffer` pass-through, frame sink.
- Needs a later patch: certificate pinning hook (libre), TURN over TCP/TLS inside ICE, ICE restart.
- Not supported by baresip: trickle ICE, REMB/TWCC bitrate adaptation, software AEC without the external WebRTC library, ZRTP without libzrtpcpp.

## 8. Contact parameter proof

See `ContactParameterProof.md`. PASS at both the libre level and through the patched baresip API, with traces in this directory.

## 9. Open items and inputs still needed

1. Done: built and verified on macOS (§3.4, §5). Still not built: `MODULE_SET=full` (libvpx commit not pinned yet) and the optional `ios-x86_64-simulator` slice.
2. Confirm that iOS 17.0 is final. Verified toolchain: Xcode 27.2 (27B52), SDK 27.2.
3. Confirm SPM binary target as the distribution channel (assumed yes; the script already produces the zip + checksum).
4. Codec list: assumed Opus + G.711 + H.264; G.722 (needs spandsp or libg722) and VP8 are optional.
5. Reference REGISTER packet and reference SDP offer/answer from the target deployment, to turn `verify_trace.py` into the "compare against reference packet" helper requested in §3 of the brief.
6. SIP server transports/ports and a test endpoint for interop (not needed until Phase 1 integration tests).
7. Decision on the three "later patch" items (pinning hook, TURN-TCP/TLS in ICE, ICE restart) versus documenting them as limitations for the first release.

## 10. Proposed C ABI

See [`../C-ABI.md`](../C-ABI.md) and `Core/include/baresip_kit.h`.
