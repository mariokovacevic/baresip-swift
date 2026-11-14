# Building

## Requirements

- macOS with Xcode 16 or newer (verified with Xcode 27.2), CMake 3.18+ (`brew install cmake`), Python 3.
- For the host build on Linux: cmake, a C compiler, libssl-dev, zlib, yasm (for libvpx), Python 3.

This page covers the XCFramework, the host build and CI. Building the Android core and libraries
(`PLATFORM=android`, Gradle) is described in [Android.md](Android.md#building-from-source).

## XCFramework

```bash
Build/build-xcframework.sh
```

Produces `Build/out/BaresipKitCore.xcframework` with separate iOS device arm64, iOS simulator arm64 and macOS arm64 slices, `BaresipKitCore.xcframework.zip` and `Build/out/checksum.txt` for the SPM binary target. The archive contains libre, baresip (static modules), OpenSSL, Opus, the BaresipKitCore facade and, on Apple platforms, the VideoToolbox and camera modules.

| Variable | Values | Default |
|---|---|---|
| `MODULE_SET` | `minimal`, `default`, `full` (adds VP8 via libvpx) | `default` |
| `SLICES` | `ios-arm64`, `ios-arm64-simulator`, `ios-x86_64-simulator`, `macos-arm64` | iOS device, iOS simulator and macOS, all arm64 |
| `PLATFORM` | `ios`, `host`, `android` (see [Android.md](Android.md#building-from-source)) | `ios` |
| `SANITIZE` | `address,undefined` or `thread` (host only) | unset |

The script clones each pinned source (`Build/versions.env`), verifies the commit, applies `Patches/*.patch`, builds OpenSSL, Opus, libvpx (full), libre, baresip and the facade per slice, merges the archives with `libtool -static` and runs `xcodebuild -create-xcframework`. `OUT_DIR` must not contain symlinks (CMake path resolution). A checkout in `Build/.deps` that is not at the pinned commit is deleted and cloned again, and the libre and baresip checkouts are reset and cleaned (`git clean -fdx`) before the patches are applied, so do not keep work in them. OpenSSL is configured with `no-autoload-config` and with fixed directories (`/etc/ssl` for the configuration, `/usr/lib/ossl-modules` for engines and providers, neither of which is used), so the libraries never read a configuration file on their own and do not contain the build path.

## Using the package

`Package.swift` resolves the `BaresipKitCore` binary target in two ways:

- **Local build**: on the default branch, where `coreReleaseURL` is empty, or anywhere with the
  environment variable `BARESIPKIT_LOCAL_CORE=1`, the target uses
  `Build/out/BaresipKitCore.xcframework`, so run the build script first.
- **Release**: at a release tag, `coreReleaseURL` and `coreReleaseChecksum` name the published
  asset, and SwiftPM downloads and verifies it. A local `Build/out` is ignored there unless
  `BARESIPKIT_LOCAL_CORE=1` is set.

Apps add a checkout as a local package (`.package(path: "../baresipkit")`), or a released version
by URL. See [Releasing.md](Releasing.md#how-swiftpm-resolves-the-core).

## Public API baselines

CI fails when the public Kotlin API of a library changes without its baseline. The baselines are
the ABI dumps in `Android/<library>/api/<library>.api`, written by the Kotlin Gradle plugin's ABI
validation. They cover binary compatibility, so a changed signature, a removed overload or a new
constructor parameter all show up. In `Android/`:

```bash
./gradlew checkKotlinAbi
./gradlew updateKotlinAbi
```

`checkKotlinAbi` compares the compiled libraries with the dumps; `updateKotlinAbi` rewrites them.
Commit the dumps together with the API change, and describe the change in `CHANGELOG.md`.

## Releasing

Cutting a release, version numbering and recovering from a failed release run are covered in
[Releasing.md](Releasing.md).

## Host build and core tests

```bash
PLATFORM=host MODULE_SET=full SANITIZE=address,undefined Build/build-xcframework.sh
HOSTIP=<interface address> PREFIX=Build/out/host/prefix Tests/Core/run_tests.sh
```

`SANITIZE` builds libre, baresip, Opus and the facade of the host prefix with the given sanitizers (OpenSSL and libvpx are built without); CI does this on Linux, so the patched network code runs under ASan and UBSan in the core tests, the fuzzer and the integration suite. Delete `Build/out/host` when you change `SANITIZE`, because Opus is not rebuilt once it is in the prefix. `BUILD_ONLY=1` makes `run_tests.sh` stop after building the test binaries.

ThreadSanitizer needs its own prefix, and `SANITIZE=thread` for the build and for the tests:

```bash
OUT_DIR=Build/out/tsan PLATFORM=host MODULE_SET=full SANITIZE=thread Build/build-xcframework.sh
SANITIZE=thread BUILD_DIR=Build/out/tsan/core-tests HOSTIP=<interface address> PREFIX=Build/out/tsan/host/prefix Tests/Core/run_tests.sh
```

With `thread`, libre, baresip and the facade use libre's pthread wrappers instead of C11 threads, because ThreadSanitizer does not intercept glibc's `thrd_create` and crashes in the first thread it creates. CI runs this suite in its own job.

`run_tests.sh` compiles the facade and the C tests with ASan/UBSan and runs: unit tests, registration against a Digest-challenging registrar (UDP and TLS with a private CA, pinning and a missing-CA case), registering again and updating the Contact parameters during an unanswered REGISTER against a registrar that answers late and checks that it still holds the binding, a wrong-password case, two-process audio calls (plain and with ICE), a camera preview with `fakevideo`, and a two-process VP8 video call. `HOSTIP` must be a non-loopback address because baresip excludes loopback interfaces.

## Fuzzing

```bash
CC=clang RUNS=300000 PREFIX=Build/out/host/prefix Tests/Fuzz/run_fuzz.sh
```

Builds a libFuzzer harness over the parsing code the facade owns (Contact parameter encoding, log redaction, ICE module event parsing, H.264 RTP depacketization and its Annex B to AVCC conversion). Where libFuzzer is not available, `FUZZ_MODE=driver` builds a mutation driver with ASan/UBSan instead.

## CI

`.github/workflows/ci.yml` runs on every push and pull request. Its jobs run in parallel:

| Job | Runs |
|---|---|
| `lint` | SwiftFormat, SwiftLint and clang-format |
| `linux-core` | the host build under ASan/UBSan, the core test suite and the fuzzers |
| `android` | the core for both Android ABIs, the Kotlin libraries, ktlint, the JVM tests against the host core, and Zvono |
| `android-emulator` | the instrumented tests and Zvono's UI tests and screenshots on an Android emulator, against a TLS registrar, a SIP peer and coturn on the runner |
| `macos` | the XCFramework, the Swift package for iOS, the simulator and macOS, its tests on macOS and a simulator, and the documentation |
| `macos-core` | the host build and the core test suite on macOS |
| `sample-app` | the sample app for the simulator and a device, its UI test and its screenshots |
| `integration` | the integration suite against Asterisk and coturn in Docker |

The pinned sources and built prefixes are cached under a key made from `Build/versions.env`, the module sets, the build script, `Build/cmake` and `Patches`, so the C core is rebuilt only when one of them changes. `sample-app` builds every prefix the macOS jobs use and saves that cache; `macos` and `macos-core` only restore it.
