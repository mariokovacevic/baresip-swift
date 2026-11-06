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

`Package.swift` points the binary target at `Build/out/BaresipKitCore.xcframework`. For a release, upload the zip and switch the target to `url:` + `checksum:` from `Build/out/checksum.txt`. The checksum changes with every rebuild because the archives carry timestamps, so compute it from the exact zip you publish.

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
