# Building

## Requirements

- macOS with Xcode 16 or newer (verified with Xcode 27.2), CMake 3.18+ (`brew install cmake`), Python 3.
- For the host build on Linux: cmake, a C compiler, libssl-dev, zlib, yasm (for libvpx), Python 3.

## XCFramework

```bash
Build/build-xcframework.sh
```

Produces `Build/out/BaresipKitCore.xcframework` with separate iOS device arm64 and iOS simulator arm64 slices, `BaresipKitCore.xcframework.zip` and `Build/out/checksum.txt` for the SPM binary target. The archive contains libre, baresip (static modules), OpenSSL, Opus, the BaresipKitCore facade and, on Apple platforms, the VideoToolbox and camera modules.

| Variable | Values | Default |
|---|---|---|
| `MODULE_SET` | `minimal`, `default`, `full` (adds VP8 via libvpx) | `default` |
| `SLICES` | `ios-arm64`, `ios-arm64-simulator`, `ios-x86_64-simulator` | device + simulator arm64 |
| `PLATFORM` | `ios`, `host` | `ios` |
| `SANITIZE` | `address,undefined` (host only) | unset |

The script clones each pinned source (`Build/versions.env`), verifies the commit, applies `Patches/*.patch`, builds OpenSSL, Opus, libvpx (full), libre, baresip and the facade per slice, merges the archives with `libtool -static` and runs `xcodebuild -create-xcframework`. `OUT_DIR` must not contain symlinks (CMake path resolution).

## Using the package

`Package.swift` resolves the `BaresipKitCore` binary target in two ways:

- **Local build**: when `Build/out/BaresipKitCore.xcframework` exists (after running the build script), or when no release has been made yet, the target uses that path.
- **Release**: otherwise it downloads the zip from the GitHub release named in `coreReleaseURL` and verifies `coreReleaseChecksum`.

Consumers add the package by URL in Xcode (File > Add Package Dependencies) once a release exists:

```swift
.package(url: "https://github.com/mariokovacevic/baresip-swift.git", from: "1.0.0")
```

## Releasing

Run the **Release** workflow from the Actions tab with a version such as `1.0.0`. It checks out `source_ref` (`main` by default), builds the XCFramework on a macOS runner, writes the release URL and checksum into `Package.swift` in a release commit on top of it, pushes only the tag `v<version>` that points to that commit, and creates a GitHub release with the XCFramework zip, its checksum and a zip of the license texts. The branch itself is not changed: SwiftPM resolves versions by tag. The checksum changes with every rebuild because the archives carry timestamps, so it is always computed from the exact zip that is published.

## Host build and core tests

```bash
PLATFORM=host MODULE_SET=full Build/build-xcframework.sh
HOSTIP=<interface address> PREFIX=Build/out/host/prefix Tests/Core/run_tests.sh
```

`run_tests.sh` compiles the facade and the C tests with ASan/UBSan and runs: unit tests, registration against a Digest-challenging registrar (UDP and TLS with a private CA, pinning and a missing-CA case), a wrong-password case, two-process audio calls (plain and with ICE), a camera preview with `fakevideo`, and a two-process VP8 video call. `HOSTIP` must be a non-loopback address because baresip excludes loopback interfaces.

## Fuzzing

```bash
CC=clang RUNS=300000 PREFIX=Build/out/host/prefix Tests/Fuzz/run_fuzz.sh
```

Builds a libFuzzer harness over the parsing code the facade owns (Contact parameter encoding, log redaction, ICE module event parsing). Where libFuzzer is not available, `FUZZ_MODE=driver` builds a mutation driver with ASan/UBSan instead.

## CI

`.github/workflows/ci.yml` runs the Linux host suite and the macOS XCFramework build, the host suite, the simulator package build and XCTest on every push and pull request.
