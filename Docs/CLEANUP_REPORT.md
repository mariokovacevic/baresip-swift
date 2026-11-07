# Cleanup report

The code quality and open-source readiness pass described in [CLEANUP_AUDIT.md](CLEANUP_AUDIT.md). Every step was a separate Conventional Commit on `claude/zen-keller-jl2mtg`, and CI ran on every push.

## What changed

### Structure

- `Sources/BaresipKit` is grouped by feature: `Engine`, `Account`, `Call`, `Media`, `Network`, `Messaging`, `Diagnostics`. Each public type has its own file, and `BaresipEngine` is split into extensions per feature.
- All C access lives in `Sources/BaresipKit/Interop`. `CoreEngine` wraps the engine handle and every `bsk_*` call; the conversions between Swift values and C structs are extensions there. No other file imports `BaresipKitCore`.
- The CallKit adapter is split into configuration, push matching, event handling and provider delegate files. The PushKit adapter is split into the token type and the adapter.
- The sample app has one view or type per file, and `CallModel` is split into extensions per feature.
- The Swift tests mirror the source folders (`Account`, `Engine`, `Media`, `Network`, `CallKit`).
- `Docs/` contains the user documentation. The feasibility work is in `Docs/Research`, the device test is a checklist (`Docs/DeviceTesting.md`), and the AI-agent verification prompts are gone.

### Code style and safety

- Swift 6 language mode with strict concurrency for the package and the sample app. The package builds for the simulator and a device with warnings as errors.
- Every `@unchecked Sendable` and every unsafe pointer boundary has a `// SAFETY:` note naming the invariant. CallKit actions and push payloads cross into tasks through a documented box.
- No force unwraps, `try!` or `fatalError` outside tests; the UI test no longer uses an implicitly unwrapped optional.
- The C facade compiles with `-Wall -Wextra -Wshadow -Werror`; third-party headers are included as system headers.
- Magic numbers in the touched code became named constants (SIP status codes in the CallKit adapter, recorder timing, time unit conversions).

### Tooling

- `.clang-format` (clang-format 18.1.3), `.swiftformat`, `.swiftlint.yml` (documented thresholds, no blanket disables) and `.editorconfig`.
- `Scripts/format.sh` and `Scripts/lint.sh`, used the same way by CI and contributors. The whole tree was formatted in two `style:` commits.
- CI: a lint job that prints the formatter's diff on failure; Swift builds for simulator and device with warnings as errors; a DocC build with warnings as errors; the existing Linux, macOS, simulator, sample app UI test and Asterisk/coturn integration jobs.

### Public API

See [API_CHANGES.md](API_CHANGES.md). `ContactParameter`, `TURNServer` and `BaresipEngine.resume()` were renamed, and the old names remain as deprecated aliases. `BaresipMediaEvent.unknown` was added, and the placeholder `BaresipVideoSupport` was removed. Every public symbol has a DocC comment. The DocC catalog has Getting Started, Audio Session, Video, CallKit, PushKit and Push Contact Parameters articles.

### Open-source files

README (feature status table, requirements, installation, example), CONTRIBUTING, CODE_OF_CONDUCT (Contributor Covenant 2.1), SECURITY (private vulnerability reporting), CHANGELOG (Keep a Changelog), issue templates for bug reports (with redaction guidance) and feature requests, a pull request template. DEPENDENCIES lists the development tools, and every patch in `Patches/README.md` has a rationale and an upstream status.

### Repository data

- A tracked `__pycache__` file was removed, and `.gitignore` was replaced with the entries this project needs.
- `.mailmap` maps the work e-mail address in three early commits to the personal address, so `git log` and GitHub show one identity.
- Example data uses `example.com`, `example.invalid` and the RFC 5737 documentation ranges; no real host names, IP addresses, phone numbers or credentials were found in the tree or in the history.

## Verification

CI run 57 on `61cc3c6` passed every job:

- the lint job (clang-format, SwiftFormat and SwiftLint in strict mode)
- the Swift package build for the simulator and a device in Swift 6 mode, with warnings as errors
- DocC for all five products, with warnings as errors
- the C core tests on macOS, including H.264 through VideoToolbox, and on Linux under ASan and UBSan, plus the libFuzzer run
- XCTest on an iPhone simulator (18 tests)
- the sample app build for the simulator and a device, with warnings as errors
- the sample app UI test, which registers over TLS with a private CA, checks that a wrong pin fails, registers again, calls a peer and hangs up
- the Asterisk and coturn integration suite

The UI test needed fixes in the test and its fixtures, not in the SDK: fields are found by identifier, the lazy form is scrolled in short steps, the system password prompt is dismissed, and the TLS test registrar forwards calls to the peer as a minimal stateless proxy.

## Bugs fixed along the way

Reported separately because they change behavior:

- Call recording wrote the WAV file on the real-time audio threads, and the two channels drifted apart when packets arrived in bursts. Writing now happens on the engine thread, and the channels stay aligned.
- Recorder sample rate and buffers were not reset between recordings, and a lookup could take a reference to a recorder that was already being freed.
- Sample app: video state was shared between calls, switching calls dropped the transfer consultation, video panes did not follow the current call, conversations were ordered by their first message, and the Open button on an incoming call row did nothing.
- `BaresipCallKitAdapter` kept itself alive through its event loop.
- `reject(callID:statusCode:)` trapped for status codes outside `UInt16`.
- Unknown media events from a newer core were reported as `.audioStarted`.
- In the CallKit adapter, a `where` clause in a multi-pattern `case` would have reported outgoing progress for incoming calls; it was rewritten so the condition applies to every pattern.

## Intentionally left

- `Core/` stays the C source root instead of `Sources/BaresipKitCore`, because SwiftPM cannot build the C core: it needs the prebuilt baresip, libre and OpenSSL static libraries. The binary target keeps the name `BaresipKitCore`.
- The C tests stay in `Tests/Core`, `Tests/Fuzz` and `Tests/Integration`; they are C programs and shell scripts, not XCTest targets.
- `Tools/ContactParameterProof` stays: CI uses its TLS registrar for the sample app UI test.
- The release workflow is started manually with a version instead of on tag pushes. SwiftPM needs the XCFramework's URL and checksum inside the tagged `Package.swift`, so the workflow builds the framework first, commits the checksum, then creates the tag and the release.
- Large C files (`bsk_call.c`, `bsk_engine.c`, `vidtoolbox.c`) were formatted but not split. Splitting them touches every internal function's linkage and is best done as its own change with the C test suite as a safety net.

## Open risks

- CallKit, PushKit and the camera are only built and unit-tested in CI; they need the device checklist in `Docs/DeviceTesting.md`.
- SwiftLint and SwiftFormat are installed from Homebrew at their latest versions in CI. A new release can add a rule and fail the lint job; pin them if that becomes a problem.

## Awaiting approval

- History rewrite: not done. `.mailmap` covers how the history is displayed. Removing the old address from the commit objects needs `git filter-repo` and a force push of every branch, including `main`; see section 10 of the audit.
- API proposals that break source compatibility without an alias: value-first setter arguments, transfer method names, and nesting `BaresipStatus` in `BaresipError` (listed in `API_CHANGES.md`).
