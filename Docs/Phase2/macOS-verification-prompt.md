# macOS verification prompt for Phase 2 (video)

```text
Repository: mariokovacevic/baresip-swift, branch claude/zen-keller-jl2mtg.
Context: Phase 2 added video to the C facade. On Linux it is verified: a
fakevideo preview and a two-process VP8 video call deliver frames to the
local and remote sinks under ASan/UBSan (Tests/Core/test_video.c). Two new
Apple-only sources have never been compiled: Core/src/apple/vidtoolbox.c
(H.264 via VideoToolbox, libre h264 packetizer, SDP packetization-mode 0/1)
and Core/src/apple/bskcapture.m (AVFoundation camera, NV12 frames, front/back,
rotation). Sources/BaresipKitVideo/BaresipVideoView.swift (UIKit,
AVSampleBufferDisplayLayer) is also uncompiled. Read Core/src/bsk_video.c,
Core/CMakeLists.txt and Docs/Phase0/C-ABI.md first.

Also new since then and host-verified on Linux: Patches/0004 (libre server
verify handler, used for SPKI pinning in Core/src/bsk_tls.c), Patches/0005
(ICE module events mapped to BSK_EVENT_ICE), TLS registration tests
(Tools/ContactParameterProof/tls_registrar.py) and an ICE call stage in
Tests/Core/run_tests.sh. They are part of step 1.

Do this in order and stop for review after step 7:

1. `PLATFORM=host MODULE_SET=full Build/build-xcframework.sh` then
   `HOSTIP=<en0 address> PREFIX=Build/out/host/prefix Tests/Core/run_tests.sh`.
   The full set builds libvpx (pinned d168454). On macOS the facade now also
   compiles vidtoolbox.c and bskcapture.m (CMake enables OBJC on APPLE).
   Fix compile errors in those two files at the root cause; keep the public
   functions declared in Core/src/apple/vidtoolbox.h. Every stage incl.
   "video preview" and "two-process video call" must PASS and the run must
   end with "ALL CORE TESTS PASSED". The camera is not used by the tests
   (fakevideo), so no camera permission is needed.

2. H.264 proof on the host: add a `--codec H264` option (or env
   BSK_TEST_VCODEC) to Tests/Core/test_video.c so the two-process call can
   negotiate H264 instead of VP8, and run it on this Mac. Both processes must
   deliver remote frames through vidtoolbox encode/decode. Report the SDP
   fmtp line from the trace (enable log_sip_trace in the test if needed) and
   the frame counts. If VideoToolbox refuses to create a session for the
   fakevideo size (320x240), use 640x480.

3. `MODULE_SET=default Build/build-xcframework.sh` for the iOS slices must
   end with exit 0 and `nm` must show vidtoolbox_init and bskcapture_init in
   both slices.

4. `xcodebuild build -scheme BaresipKit-Package -destination
   'generic/platform=iOS Simulator'` with zero warnings, then
   `xcodebuild test -scheme BaresipKit-Package -destination
   'platform=iOS Simulator,name=iPhone 17'`. The existing VideoSinkTests
   assert that the core rejects sinks; the core now accepts them, so rewrite
   that test: with modules including fakevideo and
   video.sourceModule = "fakevideo", startVideoPreview must deliver at least
   three frames to a renderer within 3 s, stopVideoPreview must stop them,
   and setVideoRenderer on an unknown call must fail with .notFound.
   Add a test that BaresipVideoView.renderer accepts a frame built from a
   CVPixelBuffer without crashing.

5. Camera smoke test on the simulator is not possible (no camera). Build the
   Examples target only if it exists; otherwise skip.

6. Update Docs/Phase0/CompatibilityMatrix.md rows for H.264, camera capture
   and remote rendering from "facade (new module)" to implemented, with the
   file names, and note any VideoToolbox limitation you hit.

7. Commit, push to claude/zen-keller-jl2mtg, and summarize: what passed,
   what you changed and why, exact output of anything failing, frame counts
   from the H.264 run, and any remaining gap.

Rules: do not change pinned versions in Build/versions.env, do not add
comments inside code, keep any upstream change as a patch in Patches/ with
a row in Patches/README.md, do not change system or security settings,
report failures with the exact output.
```
