# macOS verification prompt for Phase 1

Paste into Claude Code on a Mac with Xcode, in a checkout of `mariokovacevic/baresip-swift` on branch `claude/zen-keller-jl2mtg`:

```text
Repository: mariokovacevic/baresip-swift, branch claude/zen-keller-jl2mtg.
Context: Phase 1 added the C facade (Core/), its host test suite (Tests/Core)
and the Swift layers (Package.swift, Sources/BaresipKit*, Tests/BaresipKitTests).
The Swift code was written on Linux without a Swift toolchain and has never
been compiled. Your job is to compile and test it here, fixing compile errors
without changing the public API shape or the C ABI unless a fix needs it.

Do this in order and stop for review after step 7:

1. Report xcodebuild -version and swift --version.

2. Run `MODULE_SET=default Build/build-xcframework.sh`. It now also builds the
   facade (Core/) per slice and merges it into libBaresipKitCore.a. Fix any
   failure in Core/ for the iOS SDK (likely candidates: audiounit-specific
   includes, TARGET_OS_IPHONE guards, missing <stdlib.h>).

3. Run the host test suite with sanitizers:
   `PLATFORM=host MODULE_SET=default Build/build-xcframework.sh` then
   `PREFIX=Build/out/host/prefix Tests/Core/run_tests.sh`. On macOS the
   two-process call test needs a non-loopback interface address; pass
   HOSTIP=<en0 address> if auto-detection picks a Tailscale/VPN address.
   All three stages must print PASS.

4. `swift build` for the package with the iOS simulator destination:
   `xcodebuild -scheme BaresipKit -destination 'generic/platform=iOS Simulator' build`
   (or `swift build --sdk ... --triple arm64-apple-ios17.0-simulator`). Fix
   Swift compile errors. Known risk areas: C enum imports (bsk_* enums are
   imported as structs with rawValue; the Swift wrappers use `.rawValue`),
   fixed-size char arrays imported as tuples (handled by stringFromCArray),
   the @convention(c) callbacks in BaresipEngine.installCallbacks, and
   StrictConcurrency warnings. Keep the API in Sources/BaresipKit stable.

5. Run `xcodebuild test -scheme BaresipKit -destination 'platform=iOS
   Simulator,name=iPhone 17'` (any iPhone simulator with iOS 17+). The
   EngineLifecycleTests need the `ausine`/`aufile` modules, which are in the
   default module set.

6. Build the four adapter targets (BaresipKitAudio, BaresipKitVideo,
   BaresipKitCallKit, BaresipKitPushKit) for the simulator and fix errors.

7. Commit with a clear message, push, and summarize: what compiled, what you
   changed, test results, and any API gap you noticed between the Swift layer
   and the C ABI.

Rules: do not change pinned versions, do not add comments inside code, keep
patches minimal and in Patches/, report failures with exact output.
```
