# macOS verification prompt for Phase 3 (video, TLS pinning, ICE events, sample app, CI)

```text
Repository: mariokovacevic/baresip-swift, branch claude/zen-keller-jl2mtg.
Context: everything up to the frame sinks is verified on both Linux and
macOS. Since then, on Linux only (all host tests pass under ASan/UBSan and
the facade parsers survived 300k fuzz iterations):
- Core/src/apple/vidtoolbox.c (H.264 via VideoToolbox) and
  Core/src/apple/bskcapture.m (camera) were written, never compiled;
- Sources/BaresipKitVideo/BaresipVideoView.swift (AVSampleBufferDisplayLayer)
  was written, never compiled;
- Patches/0004 (libre tls_set_verify_server_handler) with SPKI pinning in
  Core/src/bsk_tls.c, Patches/0005 (ICE module events) mapped to
  BSK_EVENT_ICE and statistics, TLS registration tests, an ICE call stage,
  Tests/Fuzz (libFuzzer harness), .github/workflows/ci.yml,
  Examples/SampleApp (SwiftUI, xcodegen project.yml) and
  Tests/Integration (Asterisk + coturn docker-compose with
  Tests/Core/test_integration.c).
Read Docs/README.md, Docs/Limitations.md and Core/src/bsk_video.c first.

Do this in order and stop for review after step 9:

1. `PLATFORM=host MODULE_SET=full Build/build-xcframework.sh` then
   `HOSTIP=<en0 address> PREFIX=Build/out/host/prefix Tests/Core/run_tests.sh`.
   On macOS the facade now compiles vidtoolbox.c and bskcapture.m. Fix compile
   errors in those files at the root cause; keep the functions declared in
   Core/src/apple/vidtoolbox.h. Every stage incl. TLS (four modes), the ICE
   call, the video preview and the VP8 video call must PASS; the run must end
   with "ALL CORE TESTS PASSED". Note: the TLS registrar is Python
   (Tools/ContactParameterProof/tls_registrar.py) and needs the self-signed
   certificate the script generates with openssl.

2. H.264 proof on the host: add BSK_TEST_VCODEC (default VP8) to
   Tests/Core/test_video.c so the two-process call can negotiate H264, and
   run it with BSK_TEST_VCODEC=H264. Both processes must deliver remote
   frames through vidtoolbox. If VideoToolbox refuses 320x240, use 640x480.
   Report the SDP fmtp line and the frame counts.

3. `CC=clang RUNS=300000 PREFIX=Build/out/host/prefix Tests/Fuzz/run_fuzz.sh`
   (libFuzzer with Apple clang; if -fsanitize=fuzzer is unavailable, use
   FUZZ_MODE=driver).

4. `MODULE_SET=default Build/build-xcframework.sh`; `nm` must show
   vidtoolbox_init, bskcapture_init and bsk_tls_install_pins in both slices.

5. `xcodebuild build -scheme BaresipKit-Package -destination
   'generic/platform=iOS Simulator'` with zero warnings, then
   `xcodebuild test -scheme BaresipKit-Package -destination
   'platform=iOS Simulator,name=iPhone 17'`. Rewrite VideoSinkTests for the
   working core: with modules incl. fakevideo and video.sourceModule =
   "fakevideo", startVideoPreview must deliver >= 3 frames within 3 s,
   stopVideoPreview must stop them, setVideoRenderer on an unknown call must
   fail with .notFound. Add a BaresipVideoView test that enqueues a frame
   built from a CVPixelBuffer without crashing.

6. Sample app: `brew install xcodegen` if needed, then in Examples/SampleApp
   run `xcodegen generate` and
   `xcodebuild build -project BaresipKitSample.xcodeproj -scheme BaresipKitSample -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`.
   Fix compile errors in the sample without changing the SDK API.

7. CI: validate .github/workflows/ci.yml with `actionlint` if available
   (brew install actionlint); fix syntax issues only.

8. If Docker Desktop is available, run
   `PREFIX=Build/out/host/prefix HOSTIP=<en0> Tests/Integration/run_integration.sh`
   and report; on macOS host networking needs Docker Desktop 4.34+ with the
   host-networking option enabled. If not available, say so and skip.

9. Update Docs/Phase0/CompatibilityMatrix.md rows for H.264 and camera
   capture to "verified on macOS" with any VideoToolbox limitation, commit,
   push to claude/zen-keller-jl2mtg, and summarize: what passed, what you
   changed and why, exact output of anything failing, H.264 frame counts,
   and remaining gaps.

Rules: do not change pinned versions in Build/versions.env, do not add
comments inside code, keep any upstream change as a patch in Patches/ with
a row in Patches/README.md, do not change system or security settings,
report failures with the exact output.
```
