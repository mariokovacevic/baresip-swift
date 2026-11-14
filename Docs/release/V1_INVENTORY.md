# BaresipKit v1.0.0 inventory

State of branch `claude/zen-keller-jl2mtg` at commit `0844964` (2026-11-14). Every number in this file
was produced from that tree; where something could not be produced in the review environment,
it says so.

## 1. Release history and tags

| Item | Value |
|---|---|
| Default branch `main` | `2bfa144` "Initial commit": an empty starting point; no release work is on it |
| Review branch | `claude/zen-keller-jl2mtg`, 4 commits on top of `main` (see section 4) |
| Published GitHub release | **`1.0.0`**, published 2026-11-10, tag `1.0.0` → `7fc8970` ("Initial commit" of an earlier history). That commit is not an ancestor of any current branch: the history was replaced after the release |
| Contents of release `1.0.0` | iOS only (no `Android/`, no LiveCommunicationKit module). Its `Package.swift` has an empty `coreReleaseURL`, so the package falls back to a local `Build/out/BaresipKitCore.xcframework` that is not in the repository: SwiftPM cannot resolve the tag for a consumer. Its own `CHANGELOG.md` says "Beta, not released yet" |
| Local-only tag | `v1.0.0` → `b57cb19` "Release v1.0.0: point BaresipKitCore at the release asset", not pushed, not on any branch |
| Android version | `VERSION_NAME=0.1.0-SNAPSHOT` (`Android/gradle.properties:6`) |
| Swift package version | taken from the git tag only; no version constant in sources |

## 2. Repository tree and module boundaries

```
Core/                     C facade over baresip/libre (the only code both SDKs link)
  include/baresip_kit.h           public C ABI, version 0.12 (BSK_ABI_VERSION_*)
  include/baresip_kit_android.h   Android-only additions (JNI_OnLoad / Java VM handoff)
  src/                            facade: engine, accounts, calls, media, video, hold music,
                                  session timers, TLS trust, statistics, recording, messages
  src/apple/                      VideoToolbox H.264 codec, AVFoundation camera source, trust
  src/android/                    MediaCodec H.264 codec, Camera2 source glue, AAudio
  third_party/g722/               vendored G.722 codec (sippy/libg722)
Patches/                  28 patches to libre and baresip (0013 unused), rationale in Patches/README.md
Build/                    build-xcframework.sh (XCFramework and Android static libs), pins, module sets
Package.swift             Swift package: 7 products + internal targets
Sources/
  BaresipKitBridge        C helpers for the event union (internal target)
  BaresipKit              engine, accounts, calls, media, messages, logging, TLS, NAT, lifecycle
  BaresipKitAudio         AVAudioSession controller when no system call framework owns audio
  BaresipKitVideo         remote video views, camera preview, snapshots
  BaresipKitSystemCall    internal: push-to-INVITE ledger and call bookkeeping (package access)
  BaresipKitCallKit       CallKit adapter
  BaresipKitLiveCommunication  LiveCommunicationKit adapter (iOS 17.4+)
  BaresipKitPushKit       PushKit adapter and push Contact parameters
  BaresipKitSwiftUI       BaresipPhone / BaresipPhoneCall observable state
Android/                  Gradle project
  baresipkit              Kotlin API over JNI (src/main/cpp), carries libbaresipkit.so
  baresipkit-audio        audio focus, communication mode, routing
  baresipkit-video        remote video, Camera2 preview, MediaCodec
  baresipkit-telecom      Jetpack core-telecom adapter, push ledger
  baresipkit-push         Firebase Cloud Messaging Contact parameters and pushed calls
  baresipkit-compose      Compose state holders and video composables
  zvono                   sample app (Compose)
Examples/SampleApp        iOS sample app (XcodeGen), with a notification content extension
Tests/
  Core/                   C unit and multi-process tests (ASan/UBSan), scripted SIP peer
  Fuzz/                   libFuzzer targets for facade parsers
  Integration/            Docker: Asterisk 23.5.0 and coturn 4.6.3
  BaresipKitTests/        XCTest for all Swift modules
Tools/                    DoorStack (Asterisk, push gateway, APNs/FCM mocks, door station),
                          ContactParameterProof, SampleScreenshots, Sounds
Docs/                     guides (see section 7), Research/, Images/
```

Dependency direction: platform modules → `BaresipKit` / `baresipkit` → C ABI → baresip/libre.
`BaresipKitSystemCall` is used only by the CallKit, LiveCommunicationKit, PushKit and SwiftUI
targets and is not a product. On Android the push ledger lives inside `baresipkit-telecom`.

## 3. Pinned versions and licenses

Upstream sources are pinned by tag **and** commit in `Build/versions.env`; the build script
verifies the commit before building.

| Component | Version | Commit | License | Shipped in |
|---|---|---|---|---|
| libre (includes librem) | v4.13.0 | `b827bca` | BSD-3-Clause | both |
| baresip | v4.13.0 | `8a4f18c` | BSD-3-Clause | both |
| OpenSSL | 3.5.9 (LTS) | `45e844f` | Apache-2.0 | both |
| Opus | 1.6.1 | `22244de` | BSD-3-Clause | both |
| libvpx | 1.15.2 | `d168454` | BSD-3-Clause + patent grant | only with `MODULE_SET=full` |
| G.722 (sippy/libg722) | `a2688d2`, vendored | — | BSD-2-Clause / CMU / public domain | both |
| G.711 | in baresip | — | BSD-3-Clause | both |
| H.264 | OS codecs (VideoToolbox, MediaCodec) | — | platform | not shipped |
| kotlinx-coroutines | 1.11.0 | — | Apache-2.0 | Android |
| AndroidX core-telecom | 1.1.0 | — | Apache-2.0 | `baresipkit-telecom` |
| AndroidX lifecycle | 2.10.0 | — | Apache-2.0 | Android |
| Compose BOM | 2026.03.01 | — | Apache-2.0 | `baresipkit-compose` |
| Firebase Messaging | not a dependency: `baresipkit-push` takes the payload and token from the app's own `FirebaseMessagingService` | — | — | — |

Patches: 28 files, `0001`–`0028` without `0013`, applied to libre (8) and baresip (20). Each has
a section in `Patches/README.md`; upstream status is reviewed in `V1_REVIEW.md`.

Development and test images: Asterisk 23.5.0 (`andrius/asterisk`, pinned by digest, GPL-2.0),
coturn 4.6.3 (BSD-3-Clause).

## 4. Commits

`main` holds only an empty "Initial commit". All work is on the review branch; the history before
the published `1.0.0` was squashed, so changes cannot be listed commit by commit before
`4a98c6f`.

| Commit | Kind | Summary |
|---|---|---|
| `4a98c6f` | feature (squash) | Whole kit: C core, Swift package, Android libraries, samples, tests, docs |
| `3a9788f` | fix | CANCEL `Reason` other than 200/600/603 no longer ends a call as failed; spent push UUIDs not reused; precise session-timer validation error; one `BaresipError` conversion; CHANGELOG lists removed media events |
| `2fe2e83` | refactor | `SystemCallBook` shared by the CallKit and LiveCommunicationKit adapters |
| `0844964` | feature | Calls replaced by an INVITE with `Replaces` or followed after REFER keep their system call (C ABI 0.12) |

Changes relative to the published `1.0.0` tree (`git diff 7fc8970 HEAD`: 431 files,
+39 034 / −2 896), grouped:

- **Features:** Android support (6 libraries and the Zvono sample); LiveCommunicationKit adapter;
  SIP session timers (RFC 4028, patches 0024/0025); answered/declined elsewhere (RFC 3326);
  music on hold (patch 0023); call UUID header, Recents redial, phone-number handles and action
  timeouts in the system-call adapters; messages during a call; DTMF-over-SIP-INFO marking (patch
  0028); call continuity across `Replaces`/REFER; DoorStack tooling.
- **Fixes:** see `3a9788f`; patches 0026 (audio source without device) and 0027 (TURN send on the
  main thread).
- **Refactors:** push ledger and SIP identity moved from `BaresipKitCallKit` to the internal
  `BaresipKitSystemCall`; `SystemCallBook`.
- **Breaking against the published 1.0.0** (source level): `BaresipMediaEvent.audioStopped`,
  `.videoStarted`, `.videoStopped`, `.rtpTimeout` removed; new cases in the public, non-frozen
  enums `BaresipCallEndReason` and others break exhaustive `switch` statements in client code.

## 5. Public API surface

- **Swift:** `Docs/release/api/swift-public-api.md`, every `public`/`open` declaration per module
  with file and line (BaresipKit 337, BaresipKitSwiftUI 61, BaresipKitCallKit 42,
  BaresipKitLiveCommunication 37, BaresipKitPushKit 27, BaresipKitVideo 24, BaresipKitAudio 20).
  It was generated from source with grep because no Swift toolchain was available in the review
  environment; it is **not** a compiler-generated API digest.
- **Kotlin:** `Docs/release/api/kotlin-public-api.md`, generated with `javap -public` over the
  compiled classes of each library module (see that file for the command and for any module that
  could not be compiled here). The binary-compatibility-validator is **not** configured in the
  project.
- **C:** `Core/include/baresip_kit.h` (ABI 0.12) and `Core/include/baresip_kit_android.h`.

## 6. Platforms and toolchains

| Item | Declared | Where |
|---|---|---|
| iOS minimum | 16.0 | `Package.swift`, `Build/versions.env`, README |
| macOS minimum | 13.0 (Apple silicon, partial) | `Package.swift`, README |
| iOS slices | device arm64, simulator arm64; macOS arm64 | `Build/build-xcframework.sh` |
| LiveCommunicationKit | iOS 17.4+ (`@available`) | module sources |
| Swift tools / language | 6.0 / Swift 6 mode | `Package.swift` |
| Xcode | "16 or later" in docs; CI uses `macos-latest` without pinning a version | README, `Docs/iOS.md`, `.github/workflows/ci.yml` |
| Android minSdk / compileSdk / targetSdk | 28 / 36 / 36 (sample) | module `build.gradle.kts` |
| Android ABIs | arm64-v8a, x86_64 (no armeabi-v7a) | `Android/baresipkit/build.gradle.kts:20` |
| 16 KB pages | `LOAD` segments aligned to 0x4000 in both ABIs (checked with `readelf -lW`) | build output |
| NDK | 30.0.16248370 | `Build/versions.env`, `Android/baresipkit/build.gradle.kts` |
| AGP / Kotlin / Gradle | 8.13.2 / 2.4.21 / 8.14.3 | `libs.versions.toml`, wrapper |
| JDK | 21 to build (docs), bytecode target 17 | `Docs/Android.md`, module build files |
| CMake | ≥ 3.18 (core), ≥ 3.22 (Android JNI), docs say 3.22.1 | CMakeLists |

## 7. Feature status per platform

From the README matrix, checked against the code and tests:

| Feature | iOS | Android |
|---|---|---|
| Registration UDP/TCP/TLS, private CA, mutual TLS, SPKI pinning | Supported | Supported |
| Push `Contact` parameters preserved across re-registration and token updates | Supported | Supported |
| Audio: Opus, G.722, G.711 | Supported | Supported |
| Video H.264 (VideoToolbox / MediaCodec), VP8 in `full` | Supported | Supported |
| Hold/resume (local, remote), mute, DTMF RFC 4733 and SIP INFO | Supported | Supported |
| Several calls, switching | Supported | Supported |
| Blind and attended transfer; following incoming transfers | Supported | Supported |
| Call continuity across `Replaces`/REFER in the system call | Supported (CI logic only) | Supported (CI logic only) |
| SIP MESSAGE | Supported | Supported |
| Early media preview | Supported | Supported |
| SRTP (SDES), DTLS-SRTP | Supported | Supported |
| ICE, STUN, TURN UDP/TCP/TLS, ICE restart | Supported | Supported |
| Session timers (RFC 4028) | Supported | Supported |
| Music on hold | Supported | Supported |
| Network change handling, background offline | Supported | Supported |
| Recording, statistics, file log with redaction | Supported | Supported |
| System call integration | CallKit, LiveCommunicationKit: supported (device-tested by hand) | Telecom: supported (emulator) |
| Push | PushKit: supported (device-tested by hand) | FCM: partial (not tried with Google's servers) |
| SIP over WSS | Partial (untested) | Partial (untested) |
| IPv6 / NAT64 | Not verified | Not verified |
| armeabi-v7a, iOS simulator x86_64 | Not supported | Not supported |
| ZRTP, conferencing, presence, H.265 | Not supported | Not supported |

## 8. Recorded sizes

| Artifact | Size | Source |
|---|---|---|
| `libbaresipkit.so` arm64-v8a, stripped, release | 6.85 MB | Android build output, 2026-11-12, before the last three commits |
| `libbaresipkit.so` x86_64, stripped, release | 7.41 MB | same |
| `baresipkit-release.aar` | 6.67 MB | same |
| Other Android AARs | 22–86 KB each | same |
| Host `libBaresipKitCore.a` (full set, Linux, unstripped) | 19.4 MB | `Build/out/sizes.txt` |
| iOS XCFramework per slice | **not measured** in this environment (no macOS) | — |
