# BaresipKit cleanup audit

Audit for the code quality and open-source readiness pass. Nothing in this document has been changed yet; the plan at the end lists the order of work and the items that need approval.

Snapshot: branch `claude/zen-keller-jl2mtg` at `5e9e50c`, 117 tracked files, about 16 800 lines of code outside `Patches/`.

## 1. Repository tree and module boundaries

```
.
├── Package.swift                 swift-tools 5.9, iOS 17, binary target + 6 Swift/C targets
├── Build/                        build-xcframework.sh, cmake toolchain, versions.env, module-sets.env
├── Core/                         C facade (Layer 2), built into BaresipKitCore.xcframework
│   ├── CMakeLists.txt
│   ├── include/baresip_kit.h     public C ABI 0.6
│   └── src/                      bsk_engine, bsk_account, bsk_call, bsk_message, bsk_record,
│                                 bsk_video, bsk_tls, bsk_log, bsk_rate, bsk_internal.h,
│                                 apple/vidtoolbox.c, apple/bskcapture.m
├── Sources/
│   ├── BaresipKitBridge/         C shim target: bsk_bridge.c + include/bsk_bridge.h
│   ├── BaresipKit/               Swift API: BaresipEngine, Configuration, Events, Errors,
│   │                             Identifiers, Logging, Video, CInterop
│   ├── BaresipKitAudio/          BaresipAudioSessionController
│   ├── BaresipKitVideo/          BaresipVideo (frame relay), BaresipVideoView
│   ├── BaresipKitCallKit/        BaresipCallKitAdapter
│   └── BaresipKitPushKit/        BaresipPushKitAdapter
├── Tests/
│   ├── BaresipKitTests/          XCTest (BaresipKitTests, CallKitMatchingTests)
│   ├── Core/                     C tests: unit, registration, call, transfer, video, integration
│   ├── Fuzz/                     libFuzzer driver for the facade parsers
│   └── Integration/              Docker Asterisk + coturn suite
├── Tools/ContactParameterProof/  Phase 0 proof: fake registrars, trace verifier
├── Examples/SampleApp/           xcodegen project, SwiftUI app, UI test
├── Patches/                      0001–0010 baresip/libre patches + README
├── Docs/                         Architecture, Building, Integration, Limitations, Phase0–3, Final
├── .github/workflows/            ci.yml, release.yml
├── README.md, LICENSE, THIRD_PARTY_NOTICES.md, DEPENDENCIES.md
```

The layering itself is sound: C ABI (Core), C shim (Bridge), Swift API (BaresipKit), optional adapters (Audio, Video, CallKit, PushKit). The main boundary problem is that the Swift API target calls the C ABI directly (see section 6).

Differences from the target structure in the prompt:

| Target | Today | Proposal |
|---|---|---|
| `Sources/BaresipKitCore/` | `Core/` (C sources) built by CMake into an XCFramework | Keep `Core/` as the C source root. SPM cannot build it (it needs the prebuilt baresip/libre/OpenSSL static libraries), so it is not an SPM source target. The binary target keeps the name `BaresipKitCore`. Explain this in CONTRIBUTING. |
| `Tests/IntegrationTests/` | `Tests/Integration/`, `Tests/Core/`, `Tests/Fuzz/` | Keep the three C test folders (they are not XCTest). Rename only if you want the exact names. |
| `Scripts/` | `Build/*.sh`, `Tests/*/run_*.sh`, `Tools/ContactParameterProof/*.sh` | Add `Scripts/` with `lint.sh`, `format.sh`, `bootstrap.sh`, `build-xcframework.sh` (moved), `test-core.sh` (thin wrapper). |
| `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md` | missing | add |

## 2. Files that are too long, mixed or misplaced

Files over roughly 300 lines:

| File | Lines | Problem | Proposed split |
|---|---|---|---|
| `Core/src/bsk_call.c` | 1579 | Call state, answer/preview, hold, DTMF, transfer (blind, attended, transferee), ICE restart, bitrate, recording, statistics in one file | `bsk_call.c` (lifecycle, state), `bsk_call_media.c` (mute, directions, video, bitrate, ICE restart, recording), `bsk_call_transfer.c` (REFER in/out, Replaces), `bsk_call_stats.c` |
| `Core/src/bsk_engine.c` | 1152 | Engine thread, op queue, event dispatch, config, timers, network/audio session | `bsk_engine.c` (lifecycle, thread), `bsk_ops.c` (queue and run), `bsk_events.c` (dispatch, handlers), `bsk_config.c` |
| `Core/src/apple/vidtoolbox.c` | 951 | H.264 encoder and decoder together | `vidtoolbox_enc.c`, `vidtoolbox_dec.c`, `vidtoolbox.c` (module, shared) |
| `Core/src/bsk_account.c` | 789 | Validation, Contact parameters, registration | `bsk_account.c`, `bsk_contact_params.c`, `bsk_registration.c` |
| `Sources/BaresipKit/BaresipEngine.swift` | 713 | Every public operation in one class body | Extensions by feature: `BaresipEngine.swift` (lifecycle, events), `BaresipEngine+Accounts.swift`, `+Calls.swift`, `+Media.swift`, `+Messages.swift`, `+Video.swift`, `+Lifecycle.swift` (push wake, suspend, network, audio session) |
| `Examples/SampleApp/SampleApp/CallModel.swift` | 819 | Engine setup, settings apply, calls, transfer, messages, recording, events, push, `CallRow`, `ChatMessage` | `CallModel.swift` + extensions per feature; `CallRow.swift`, `ChatMessage.swift` |
| `Core/src/bsk_video.c` | 498 | acceptable, preview and sinks | optional |
| `Core/src/bsk_record.c` | 470 | acceptable, single responsibility | none |
| `Sources/BaresipKitCallKit/BaresipCallKitAdapter.swift` | 378 | configuration struct, push matching, provider delegate | `BaresipCallKitConfiguration.swift`, `BaresipCallKitAdapter+Push.swift` |
| `Sources/BaresipKit/Events.swift` | 359 | 15+ public types in one file | one file per type, grouped under `Events/` |
| `Sources/BaresipKit/Configuration.swift` | 302 | 9 configuration types plus `TLSVersion`, `TURNServer`, `ContactParameter` | one file per type under `Configuration/` |
| `Examples/SampleApp/SampleApp/CallsHomeView.swift` | 302 | home view plus `CallListRow` | move `CallListRow` to its own file |

Misplaced or unclear:

- `Sources/BaresipKit/CInterop.swift` is a grab bag of C conversion helpers (string arena, enum mapping, struct init). It belongs with the C-facing code, not next to the public types.
- `Components.swift` in the sample app mixes `Palette`, `Avatar`, `CircleButton`, `DTMFPad`, `VideoPane` and two free functions. Split into one file per view.
- `Docs/Phase0–3/*-verification-prompt.md`, `Docs/Final/device-test-prompt.md`: prompts for an AI coding agent naming the working branch. They are internal process files, not user docs.
- `Docs/Phase0/FeasibilityReport.md`, `ContactParameterProof.md`, traces and `Tools/ContactParameterProof/`: research artifacts. Useful history; move to `Docs/Research/` or drop from the public tree.

## 3. Naming inconsistencies

- Public types without the `Baresip` prefix: `TLSVersion`, `TURNServer`, `ContactParameter`. All other public types use it.
- `BaresipOSLog` is an enum used as a namespace for an `os.Logger` helper. It should be internal or named for what it does.
- `BaresipStatus` mirrors the C `bsk_status` and is public. Callers only see `BaresipError`, so it should be internal.
- `BaresipError` is a struct with a `code`, not a typed error enum. The prompt asks for typed errors with clear cases (proposal in section 9).
- Overloads with different meanings: `resume()` (engine resumes after suspend) and `resume(callID:)` (call off hold).
- Transfer naming: `transfer(callID:to: String)` (blind) and `transferAttended(callID:to: BaresipCallID)`. Swift API guidelines suggest `transfer(callID:to:)` plus `transfer(callID:replacing:)` or `blindTransfer` / `attendedTransfer`.
- `setVideoMaxBitrate(callID:bitsPerSecond:)` puts `callID` first, while `setMicrophoneMuted(_:callID:)` and `setVideoEnabled(_:callID:)` put the value first.
- `BaresipCallInfo.isOutgoing`, but the sample `CallRow.outgoing`.
- `BaresipMediaEvent(_ c:)` falls back to `.audioStarted` for unknown raw values. Unknown events are silently reported as a real event.
- C: one prefix `bsk_` everywhere, which is consistent. Module names `bskcapture`, `bskrec` and `vidtoolbox` are baresip module names and should stay.
- Folders: `Core/` versus target name `BaresipKitCore`; `Tests/Core` versus `Tests/Integration` (both are C).

## 4. Dead code, debug output, unused files and dependencies

- No commented-out code, no `print`/`NSLog`/`printf` debug output in Swift sources, no TODO/FIXME markers.
- Tracked by mistake: `Tools/ContactParameterProof/__pycache__/fake_registrar.cpython-313.pyc`.
- `.gitignore` is the GitHub Xcode template with long comment blocks, and `Build/out/` appears twice.
- `Package.swift` keeps `coreReleaseURL` and `coreReleaseChecksum` as empty strings. That is intentional until the first release, but it should come from the release workflow.
- `BaresipEngine` still needs checking for public functions no test or sample covers (`setAudioDirection`, `requestKeyframe`, `audioRouteDidChange`). These are not dead, just untested from Swift.
- Unused dependencies: none found in `Package.swift`. `module-sets.env` builds modules not linked by default. That is documented in `Docs/Building.md`.

## 5. Force unwraps, `try!`, `fatalError`, implicitly unwrapped optionals

- None in `Sources/` or the sample app.
- `Examples/SampleApp/UITests/RegistrationCallUITests.swift:4` uses `XCUIApplication!`. That is test code and allowed.

## 6. C types and unsafe pointers outside the bridge layer

No public Swift declaration exposes a C or unsafe type. Internally, `BaresipKit` uses `bsk_*` functions and structs directly:

| File | C/unsafe references |
|---|---|
| `BaresipEngine.swift` | 118 |
| `Events.swift` | 28 |
| `CInterop.swift` | 27 |
| `Video.swift` | 6 |
| `Configuration.swift` | 4 |
| `Errors.swift` | 3 |
| `Logging.swift` | 3 |

The rule "confine all `Unsafe*Pointer` and C types to the bridge layer" is not met. `BaresipKitBridge` is a C target, so Swift code cannot live there. Proposal: add an internal `Interop/` folder in `BaresipKit` that owns every `bsk_*` call and C struct conversion (`EngineHandle`, `CStringArena`, the `init(_ c:)` initializers). Public types keep only Swift values. Each unsafe boundary gets a `// SAFETY:` note.

## 7. Concurrency (Swift 6)

- The package uses `swift-tools-version: 5.9` and enables only `StrictConcurrency` as an experimental feature on `BaresipKit`. The adapters are not checked, and there is no Swift 6 language mode.
- `@unchecked Sendable` without a written justification (7 places): `BaresipEngine`, `EngineHandle`, `BaresipVideoFrame`, `VideoSinkBox`, `BaresipVideoFrameRelay`, `SendableBox`, `BaresipCallKitAdapter`, `BaresipPushKitAdapter`. Each needs a `// SAFETY:` note naming the lock or queue that protects it. Where a type can be an actor or `Sendable` value type without changing semantics, it should be.
- The sample app's `CallModel` is `@MainActor`, but `Task {}` closures in views capture the model implicitly. Swift 6 mode will flag some of these.
- I cannot run the Swift compiler in this Linux container. The real Swift 6 warning list comes from the first CI run with `swiftLanguageModes: [.v6]`. Turning that on is step 1 of the plan.

## 8. Compiler, linter and DocC warnings

- C: `-Wall -Wextra -Wshadow -Wno-unused-parameter` and three selected `-Werror=` flags. Not `-Werror` across the board, and `-Wno-unused-parameter` hides the `(void)arg` pattern used across the code. The host build is warning-free today. `-Werror` can be turned on once the vendored baresip headers are included as system headers.
- Swift: the CI build greps for `warning: .*\.swift` but does not fail on warnings. No `-warnings-as-errors`.
- No SwiftLint, swift-format, clang-format or `.editorconfig` configuration.
- DocC: no catalog. `///` comments: 0 of about 350 public declarations are documented.

## 9. Documentation gaps

- `README.md` (74 lines): no feature status table, no minimal register-and-call example that compiles, and no Xcode version.
- Missing: CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG, DocC catalog and articles (Getting Started, Audio Session, Video, CallKit, PushKit, Push Contact Parameters), issue templates, PR template.
- `Docs/Integration.md` is accurate but long. It can become the source for the DocC articles.
- `Patches/README.md` lists every patch with a reason. Upstream status (submitted / not submitted / upstream PR link) is missing per patch.
- `THIRD_PARTY_NOTICES.md` and `DEPENDENCIES.md` exist. Check that they cover OpenSSL, Opus and libvpx licenses and the exact pinned versions from `Build/versions.env`.

## 10. Data that must not be public

Working tree:

- IP addresses: only `127.0.0.1` and RFC 5737 documentation ranges. Nothing else found.
- Hostnames: only `example.com`/`example.invalid` names and public project URLs.
- Credentials: test-only values (`secret`, generated certificates at test time). No keys or certificates are committed.
- E-mail addresses: test URIs only, plus the GitHub Actions bot address in `release.yml`.
- `LICENSE` names the copyright holder. That is intended.
- The `Docs/Phase*/…-prompt.md` and `Docs/Final/device-test-prompt.md` files name the repository and the working branch `claude/zen-keller-jl2mtg`, and are written as instructions to an AI agent. Not secret, but internal; remove or rewrite as a contributor test guide.

Git history:

- **3 commits have the author e-mail `m.kovacevic@commend.site`, a company domain**: `8e6221b`, `4ccf15c`, `0c50a33` (the macOS verification commits). Their content holds no company data (build fixes and a simulator trace), but the address and domain are public once the repository is.
- No private keys, tokens (GitHub, AWS, Slack patterns), private-range IPs or `/Users/<name>` paths found anywhere in history.

Proposed history plan (needs your approval, nothing has been rewritten):

1. Preferred, no rewrite: add a `.mailmap` that maps `m.kovacevic@commend.site` to `mariofilk@gmail.com`. That changes only how `git log` and GitHub show the name. The original address is still in the commit objects.
2. Full removal: `git filter-repo --mailmap` on a fresh clone, then force-push every branch and tag. All commit hashes change, open clones and the commit hashes cited in docs (for example "verify 81133d4") go stale, and the push has to go to main as well. That needs your explicit go-ahead, because it rewrites published history.
3. Alternative: publish a new repository from a single squashed commit of the release tree and keep this one private.

## 11. Fixes found during the audit (behavior changes, reported separately)

Already fixed and pushed before this audit (`43f15b2`, `0608265`, `5e9e50c`):

- The recorder no longer writes the file on the audio threads, and the two channels no longer drift apart.
- Sample app: per-call video state, the consultation is kept when switching calls, video panes follow the current call, and conversations are sorted by the latest message.
- UI test: fields are found by identifier, because the simulator does not expose `SecureField` as a secure text field.

Still open, found while auditing:

- `BaresipMediaEvent` and any other `init(_ c:)` that fall back to a valid case for unknown raw values should map to an explicit unknown or be dropped (behavior change).

## 12. Prioritized plan

Each step is one Conventional Commit series. Builds and tests run before and after each step: Linux core tests locally, plus macOS and integration jobs in GitHub Actions.

1. `chore:` tidy the repository: remove the tracked `.pyc`, shorten `.gitignore`, add `.editorconfig`. No code changes.
2. `ci:` make the build strict: Swift 6 language mode and strict concurrency on all targets, Swift warnings fail the build, C `-Werror` on the facade. Fix what this surfaces in separate `refactor:` commits.
3. `chore:` add tooling: `.swift-format` (or SwiftFormat), `.swiftlint.yml` with a documented rule set, `.clang-format` in the existing kernel-like C style, `Scripts/lint.sh` and `Scripts/format.sh`, and a lint job in CI.
4. `style:` apply the formatters to the whole tree in one commit.
5. `refactor:` confine C interop to `BaresipKit/Interop/` with `// SAFETY:` notes. Document every `@unchecked Sendable`.
6. `refactor:` split long files (section 2), one primary type per file, group by feature (Account, Call, Media, Network, Diagnostics).
7. `refactor:` reduce the public surface: make `BaresipStatus` and `BaresipOSLog` internal. Anything else that would change public names waits for approval (step 8).
8. API proposal awaiting approval, `Docs/API_CHANGES.md`: rename `TLSVersion` → `BaresipTLSVersion`, `TURNServer` → `BaresipTURNServer`, `ContactParameter` → `BaresipContactParameter`; `BaresipError` as a typed enum (or a struct with a typed `Code` enum, which is source compatible); `resume()` → `resumeFromBackground()`; consistent argument order for the setters; transfer naming. The SDK is unreleased (0.x), so this is the cheapest moment, but it is your call.
9. `docs:` DocC catalog with the six articles and a `///` comment on every public symbol. DocC build in CI with warnings as errors.
10. `docs:` README rewrite (status table, requirements, SPM install, minimal example), CONTRIBUTING, CODE_OF_CONDUCT (Contributor Covenant 2.1), SECURITY (GitHub private vulnerability reporting), CHANGELOG (Keep a Changelog, `Unreleased` plus `0.1.0`), check THIRD_PARTY_NOTICES and DEPENDENCIES, upstream status per patch.
11. `ci:` CI with lint, device and simulator builds, unit, integration and DocC jobs; release workflow that builds the XCFramework on tags, computes the checksum and updates `Package.swift`; issue and PR templates.
12. `docs:` move the Phase 0–3 and Final prompts and the research artifacts out of the public docs, or rewrite them as a contributor device-test guide.
13. `docs:` `Docs/CLEANUP_REPORT.md` with what changed, what was left, open risks and pending API proposals.

Decisions needed before starting:

- Git history: `.mailmap` only, a `filter-repo` rewrite, or a fresh public repository (section 10).
- Public API renames in step 8: apply now (pre-1.0), or keep the current names.
- Folder layout: keep `Core/` and the three C test folders as they are (recommended), or rename them to match the prompt's tree exactly.
- Phase docs and `Tools/ContactParameterProof`: delete, or move to `Docs/Research/`.
