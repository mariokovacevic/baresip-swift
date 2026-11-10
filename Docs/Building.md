# Building

## Requirements

- macOS with Xcode 16 or newer (verified with Xcode 27.2), CMake 3.18+ (`brew install cmake`), Python 3.
- For the host build on Linux: cmake, a C compiler, libssl-dev, zlib, yasm (for libvpx), Python 3.

## XCFramework

```bash
Build/build-xcframework.sh
```

Produces `Build/out/BaresipKitCore.xcframework` with separate iOS device arm64, iOS simulator arm64 and macOS arm64 slices, `BaresipKitCore.xcframework.zip` and `Build/out/checksum.txt` for the SPM binary target. The archive contains libre, baresip (static modules), OpenSSL, Opus, the BaresipKitCore facade and, on Apple platforms, the VideoToolbox and camera modules.

| Variable | Values | Default |
|---|---|---|
| `MODULE_SET` | `minimal`, `default`, `full` (adds VP8 via libvpx) | `default` |
| `SLICES` | `ios-arm64`, `ios-arm64-simulator`, `ios-x86_64-simulator`, `macos-arm64` | iOS device, iOS simulator and macOS, all arm64 |
| `PLATFORM` | `ios`, `host` | `ios` |
| `SANITIZE` | `address,undefined` (host only) | unset |

The script clones each pinned source (`Build/versions.env`), verifies the commit, applies `Patches/*.patch`, builds OpenSSL, Opus, libvpx (full), libre, baresip and the facade per slice, merges the archives with `libtool -static` and runs `xcodebuild -create-xcframework`. `OUT_DIR` must not contain symlinks (CMake path resolution). A checkout in `Build/.deps` that is not at the pinned commit is deleted and cloned again, and the libre and baresip checkouts are reset and cleaned (`git clean -fdx`) before the patches are applied, so do not keep work in them. OpenSSL is configured with `no-autoload-config` and with fixed directories (`/etc/ssl` for the configuration, `/usr/lib/ossl-modules` for engines and providers, neither of which is used), so the libraries never read a configuration file on their own and do not contain the build path.

## Using the package

`Package.swift` resolves the `BaresipKitCore` binary target in two ways:

- **Local build**: when `Build/out/BaresipKitCore.xcframework` exists (after running the build script), or when no release has been made yet, the target uses that path.
- **Release**: otherwise it downloads the zip from the GitHub release named in `coreReleaseURL` and verifies `coreReleaseChecksum`.

There is no release yet, so `coreReleaseURL` is empty and the local build is always used. Apps add the checkout as a local package (`.package(path: "../baresip-swift")`). After the first release, they add it by URL with a version.

## Releasing

Cutting a release, version numbering and recovering from a failed release run are covered in
[Releasing.md](Releasing.md).

## Host build and core tests

```bash
PLATFORM=host MODULE_SET=full SANITIZE=address,undefined Build/build-xcframework.sh
HOSTIP=<interface address> PREFIX=Build/out/host/prefix Tests/Core/run_tests.sh
```

`SANITIZE` builds libre, baresip, Opus and the facade of the host prefix with the given sanitizers (OpenSSL and libvpx are built without); CI does this on Linux, so the patched network code runs under ASan and UBSan in the core tests, the fuzzer and the integration suite. Delete `Build/out/host` when you change `SANITIZE`, because Opus is not rebuilt once it is in the prefix. `BUILD_ONLY=1` makes `run_tests.sh` stop after building the test binaries.

`run_tests.sh` compiles the facade and the C tests with ASan/UBSan and runs: unit tests, registration against a Digest-challenging registrar (UDP and TLS with a private CA, pinning and a missing-CA case), registering again and updating the Contact parameters during an unanswered REGISTER against a registrar that answers late and checks that it still holds the binding, a wrong-password case, two-process audio calls (plain and with ICE), a camera preview with `fakevideo`, and a two-process VP8 video call. `HOSTIP` must be a non-loopback address because baresip excludes loopback interfaces.

## Fuzzing

```bash
CC=clang RUNS=300000 PREFIX=Build/out/host/prefix Tests/Fuzz/run_fuzz.sh
```

Builds a libFuzzer harness over the parsing code the facade owns (Contact parameter encoding, log redaction, ICE module event parsing, H.264 RTP depacketization and its Annex B to AVCC conversion). Where libFuzzer is not available, `FUZZ_MODE=driver` builds a mutation driver with ASan/UBSan instead.

## CI

`.github/workflows/ci.yml` runs the Linux host suite and the macOS XCFramework build, the host suite, the simulator package build and XCTest on every push and pull request.
