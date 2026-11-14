# Contributing to BaresipKit

Thank you for helping. This guide covers setting up, building, testing and sending changes.

## Setup

For the Swift package you need macOS with Xcode 16 or later, CMake 3.18 or later and Python 3;
the Android setup is in [Android](#android) below. For formatting and linting also install the
tools CI uses:

```bash
brew install cmake swiftformat swiftlint xcodegen
python3 -m pip install --user clang-format==18.1.3
```

## Build the C core

The C core (libre, baresip, OpenSSL, Opus and the BaresipKit facade in `Core/`) is built from
pinned sources into `Build/out/BaresipKitCore.xcframework`:

```bash
Build/build-xcframework.sh
```

`MODULE_SET=minimal|default|full` selects the baresip modules, and `PLATFORM=host` builds for the
machine you are on, which the C tests use. The first build downloads and verifies the pinned
sources listed in `Build/versions.env`; see [Docs/Building.md](Docs/Building.md).

`Package.swift` uses the local XCFramework whenever it exists, so after this step the package
builds in Xcode like any other.

## Run the tests

C core tests, with AddressSanitizer and UndefinedBehaviorSanitizer:

```bash
PLATFORM=host MODULE_SET=full Build/build-xcframework.sh
PREFIX=Build/out/host/prefix Tests/Core/run_tests.sh
```

Swift tests on a simulator:

```bash
xcodebuild test -scheme BaresipKit-Package -destination 'platform=iOS Simulator,name=iPhone 16'
```

Integration tests against Asterisk and coturn (Linux or macOS with Docker):

```bash
Tests/Integration/run_integration.sh
```

The sample app:

```bash
cd Examples/SampleApp && xcodegen generate && open BaresipKitSample.xcodeproj
```

Tests that need a physical iPhone are listed in [Docs/DeviceTesting.md](Docs/DeviceTesting.md).

## Android

The C core and the patches are shared, so a change to them has to build and pass on both
platforms. You need JDK 21, the Android SDK with platform 36 and
NDK `30.0.16248370` ([Docs/Android.md](Docs/Android.md#building-from-source) has the
details):

```bash
PLATFORM=android MODULE_SET=full ANDROID_NDK_HOME="$ANDROID_HOME/ndk/30.0.16248370" Build/build-xcframework.sh
PLATFORM=host MODULE_SET=full Build/build-xcframework.sh
```

```bash
cd Android && ./gradlew assembleDebug testDebugUnitTest ktlintCheck
```

Kotlin follows ktlint's `ktlint_official` style with the settings in `.editorconfig`;
`./gradlew ktlintFormat` fixes most of what `ktlintCheck` reports. The instrumented tests and
Zvono's UI tests run on an emulator in CI.

## Format and lint

```bash
Scripts/format.sh
Scripts/lint.sh
```

CI runs `Scripts/lint.sh` and fails on any difference. C code follows the style in
`.clang-format` (tabs, Linux brace style, 80 columns); Swift follows `.swiftformat` and
`.swiftlint.yml`.

## Code rules

- Readable code without explaining comments. The only comments are DocC comments (`///`) on
  public Swift API, KDoc on public Kotlin API, and short `// SAFETY:` notes where unsafe
  pointers or C types cross a boundary.
- C types and unsafe pointers stay in `Sources/BaresipKit/Interop` and the bridge target.
- No force unwraps, `try!` or `fatalError` outside tests.
- Every public symbol has a DocC comment.
- Changes to baresip or libre go into `Patches/` as a small diff with a row in
  `Patches/README.md`, never into downloaded sources.
- Never log credentials, authorization headers or full push tokens.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `refactor:`,
`style:`, `docs:`, `test:`, `ci:`, `build:` or `chore:`, one concern per commit. Explain why in
the body when it is not obvious.

## Pull request checklist

- [ ] `Scripts/lint.sh` passes.
- [ ] The C tests and the Swift tests pass; for changes to the core, the patches or
  `Android/`, the Android build, its JVM tests and ktlint pass too.
- [ ] New public API has DocC comments, and `CHANGELOG.md` lists renames or removals.
- [ ] `CHANGELOG.md` has an entry under "Unreleased".
- [ ] No credentials, real hostnames, IP addresses or phone numbers in code, tests or logs; use
  `example.com` and the documentation address ranges (192.0.2.0/24, 198.51.100.0/24,
  203.0.113.0/24, 2001:db8::/32), and fictional numbers such as `+1 555 0100` to `+1 555 0199`.
- [ ] No names of companies, commercial products, other SDKs or apps; describe the behaviour
  instead.
