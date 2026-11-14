# BaresipKit v1.0.0 review

Review of commit `76037dc` against the v1.0.0 brief. Nothing outside `Docs/release/` was changed.

**How it was reviewed.**
- The C core, the Swift layer, the Kotlin/JNI layer, and build/docs/community were each read in
  full by a separate reviewer.
- Every Blocker and every security or privacy finding was then checked again by reading the code.
  Findings that could not be confirmed by reading are marked **unverified**.

**Limits of this environment.**
- **Swift:** there is no Swift toolchain. Swift findings come from reading the code, and the
  Swift API listing is generated with grep.
- **Kotlin:** classes were compiled with Gradle. The Kotlin API listing comes from `javap` on
  those classes.
- **C:** the C core was built and its full test suite run under ASan/UBSan. Everything passed.
- **Not available:** a real device, a macOS host, network access to vulnerability databases.

Severity:
- **Blocker:** must be fixed or decided before 1.0.
- **Should fix:** fix before 1.0 if reasonable.
- **Later:** 1.x backlog.
- **API** marks a change to the public Swift or Kotlin API, which needs approval before it is
  applied.
- **Behavior** marks a change in runtime behavior.

## Decisions needed before any fix

These are owner decisions. Several Blockers depend on them.

| # | Decision | Options | Recommendation |
|---|---|---|---|
| D1 | The published release `1.0.0` | (a) Withdraw it (delete the GitHub release and the `1.0.0` tag) and release this tree as `1.0.0`. (b) Keep it and release this tree as `2.0.0`. | (a). The published tag cannot be resolved by SwiftPM, so nobody could have built against it (B-01). (b) is the only SemVer-clean option if any consumer exists. |
| D2 | Is the C ABI public under SemVer? | (a) Public: freeze it and make every output struct growable (B-05). (b) Internal: ship it in lockstep with the Swift and Kotlin layers, and document it as not covered. | (b) for 1.0, (a) later. Both SDKs bundle the core of the same version, and no third-party binding exists. |
| D3 | Enums and sealed types that grow | (a) Document that minor releases may add cases (`default` / `else` needed). (b) Turn the growing ones into structs or classes with static members, or add `unknown` members. | (a) for most types. (b) for `BaresipError.Code` and the media and end-reason enums, which grow most often. |
| D4 | Kotlin public `data class`es | (a) Keep them and accept that a new option breaks binary compatibility (major release). (b) Plain classes with builders or DSLs for configurations, internal constructors for output types. | (b). Configuration types gain options in most releases. |
| D5 | Local-only refs | Delete the local tag `v1.0.0` and the local branches `backup/pre-squash` and `live-activity`, expire reflogs and gc; or release from a fresh clone. | Release from a fresh clone, then also clean this clone (B-02). |
| D6 | Untested scope | Ship 1.0 with FCM "not tried with Google's servers", WSS "untested" and no real-device measurements, stated as known limitations; or test first. | Ship as known limitations, stated in the release notes. |

## Blockers

### B-01 Published release `1.0.0` conflicts with this release
- **Location:**
  - GitHub release `1.0.0`, published 2026-11-10; tag `1.0.0` → `7fc8970`.
  - Local tag `v1.0.0` → `b57cb19`.
  - `.github/workflows/release.yml:48`, which creates `v<version>`.
- **Description:**
  - The release tag points at a commit from a history that was later replaced. That commit is not
    an ancestor of any branch.
  - Its `Package.swift` has an empty `coreReleaseURL`, so SwiftPM cannot resolve the package from
    that tag.
  - The tree changed since then in source-breaking ways: `BaresipMediaEvent` cases were removed,
    and public non-frozen enums gained cases.
  - The release workflow uses `v1.0.0` while the published tag is `1.0.0`.
- **Impact:** two tags for one version; SemVer broken if any consumer of `1.0.0` exists; confusing
  release history.
- **Fix:** D1. Then use one tag scheme, aligned with the workflow, and delete the local `v1.0.0`
  without pushing it.

### B-02 Local refs carry a company name and a work email address
- **Location:**
  - Local tag `v1.0.0`: `.mailmap`, `Docs/CLEANUP_AUDIT.md`.
  - Local branch `live-activity`: `Examples/SampleApp/README.md`,
    `Tools/DoorStack/asterisk/pjsip.conf`.
  - 342 unreachable commits in this clone.
- **Checked:** `main`, both remote branches and the remote tag `1.0.0` are clean (word-boundary
  search).
- **Impact:** a `git push --tags`, `--all` or `--mirror` from this clone would publish them.
  Whether GitHub still holds objects of the history pushed before the squash is **unverified**.
- **Fix:** D5. Never push with `--all`, `--tags` or `--mirror`. Ask GitHub support to purge
  unreferenced objects if the earlier history was ever pushed.

### B-03 Other vendors' products are named in the repository
- **Location:**
  - `README.md:64-82`: a comparison table with two other SIP SDKs, including their licensing terms
    and links.
  - A feature of another SIP SDK, used as the description of music on hold:
    `Core/include/baresip_kit.h:240`, `Core/src/bsk_hold.c:7`,
    `Sources/BaresipKit/Media/BaresipAudioConfiguration.swift:27`,
    `Sources/BaresipKit/BaresipKit.docc/AudioSession.md:97`, `CHANGELOG.md:58`,
    `Examples/SampleApp/SampleApp/Model/CallModel+Engine.swift:24`,
    `Patches/0023-baresip-stream-send-on-hold.patch:8`, `Patches/README.md:35`.
  - A vendor's SIP server named as the origin of the push parameter format:
    `Sources/BaresipKitPushKit/BaresipPushTokens.swift:6`, `Docs/iOS.md:259`,
    `Sources/BaresipKit/BaresipKit.docc/PushContactParameters.md:29`.
  - A commercial door-station product in `.github/ISSUE_TEMPLATE/interop_report.yml:16`.
- **Impact:** violates the brief's neutrality rule, and the README makes legal statements about
  third parties.
- **Fix:**
  - Remove the comparison and state BaresipKit's own licensing.
  - Describe behavior instead of naming products ("music on hold from a WAV file", "the
    `app-id`/`pn-type`/`pn-tok` parameter set").
  - Use a generic placeholder in the issue template.
  - Commit messages already in history are not rewritten.

### B-04 TLS certificate pinning can be bypassed on the system-trust path
- **Location:** `Core/src/bsk_tls.c:165-190` (`trust_handler`), `Patches/0018-re-tls-trust-handler.patch`.
- **Description:**
  - When no private CA is configured, the chain is validated by the system trust store
    (SecTrust, or OpenSSL's default store).
  - The pins are then compared with **every certificate the server sent**, not with the
    validated path. This was confirmed by reading `trust_handler`.
  - The private-CA path (`verify_handler`) is correct: OpenSSL calls it for each certificate of
    the chain it built.
- **Impact:** anyone with a chain the system trusts for the host can append the pinned
  certificate and pass the pin check. Examples are a mis-issued certificate, a compromised CA,
  or a user- or MDM-installed root. Stopping exactly this is what pinning is for.
- **Fix:**
  - Check the pins against the validated chain only: `SecTrustCopyCertificateChain` on Apple,
    `X509_STORE_CTX_get0_chain` after `X509_verify_cert`.
  - Add a test that appends a pinned certificate to a chain with an untrusted leaf path.
- **Tags:** Behavior (security fix).

### B-05 C output structs cannot grow (if the C ABI is public, D2a)
- **Location:** `Core/include/baresip_kit.h`: `bsk_call_info`, `bsk_call_statistics`, `bsk_error`,
  `bsk_video_frame`, `bsk_video_sink`, `bsk_event`, and the structs nested in the size-prefixed
  configurations.
- **Description:**
  - These structs have no size field, and the core writes `sizeof(*out)`.
  - They have already grown in 0.x (`replaces`, `video_target_bitrate_bps`), and each time a
    caller built against the older header would get writes past its buffer.
- **Fix:**
  - With D2b: document the C ABI as not covered by SemVer and shipped in lockstep.
  - With D2a: add a `size` field or reserved tails, and give `bsk_event` a size.
- Either way, set `BSK_ABI_VERSION` and `BSK_VERSION_STRING` for the release (B-12).

### B-06 No API baselines or API check on either platform
- **Location:** all `Android/*/build.gradle.kts` (no `explicitApi()`, no ABI validation),
  `.github/workflows/ci.yml` (no Swift API digest or check).
- **Impact:** after 1.0, nothing catches an accidental public API or binary break.
- **Fix:**
  - **Kotlin:** `explicitApi()` in the six libraries, plus Kotlin's ABI validation (or the
    binary-compatibility-validator) with committed `.api` dumps and an `apiCheck` in CI.
  - **Swift:** a committed `swift-api-digester` baseline per product, and
    `swift package diagnose-api-breaking-changes` against the release tag in CI.
  - **C (D2a only):** an `abidiff` or header diff check.
- **Tags:** API (visibility only).

### B-07 No stated rule for enums and sealed types that grow
- **Location:**
  - **Swift:** `BaresipEvent`, `BaresipCallState`, `BaresipError.Code`, `BaresipMediaEvent`,
    `BaresipCallEndReason`, `BaresipEngineState`, `BaresipRegistrationState`, `BaresipICEState`,
    `BaresipCandidateType`, `BaresipAudioRoute`, adapter error enums.
  - **Kotlin:** `BaresipEvent` (sealed), the enums in `States.kt`, `BaresipError.Code`.
  - **C:** `bsk_media_event` has holes at 1, 2, 3 and 7.
- **Description:** the package is a source distribution without library evolution, so adding a
  case breaks exhaustive `switch` and `when` in client code. Cases were added in 0.x already.
- **Fix:** D3, written in `Docs/STABILITY.md` and in the DocC and KDoc of each type. For the C
  ABI, "callers ignore unknown values".
- **Tags:** API, if (b) is chosen.

### B-08 Kotlin public data classes freeze every constructor
- **Location:**
  - `BaresipConfiguration.kt`, `BaresipAccountConfiguration.kt` (19 constructor parameters).
  - `BaresipCallInfo.kt`, `BaresipEvent.kt` payloads.
  - `BaresipTelecomConfiguration`, `BaresipPushTokens.kt`, `BaresipAudioRoute.kt`,
    `BaresipRedialRequest.kt`.
  - 42 data classes in total (`javap`).
- **Impact:** adding an option changes the constructor, `copy` and `componentN` signatures. That
  is a binary break for consumers resolving from Maven.
- **Fix:** D4. Configurations become classes with builders or DSLs, and output types become
  classes with internal constructors and `equals`/`hashCode`.
- **Tags:** API.

### B-09 Kotlin public API exposes types of `implementation` dependencies
- **Location:**
  - `Android/baresipkit-telecom/build.gradle.kts`: `implementation(libs.core.telecom)`, while
    `BaresipTelecomCall` exposes `CallEndpointCompat`.
  - `Android/baresipkit-compose/build.gradle.kts`: Compose UI is `implementation`, while
    `Modifier`, `Dp` and `DpSize` are in the public API.
- **Impact:** a consumer that does not add those libraries itself cannot compile against the
  public API. The sample hides this because it depends on them directly.
- **Fix:** declare them `api`, or wrap `CallEndpointCompat` in a BaresipKit type.
- **Tags:** API, if wrapped.

### B-10 Accept-all TLS is reachable in release builds
- **Location:**
  - `Core/src/bsk_config.c:136` (`insecure_skip_verify`).
  - Kotlin `BaresipTlsConfiguration.insecureSkippingServerVerification()`
    (`BaresipConfiguration.kt:217`), public in every build.
  - Swift: `BaresipTLSConfiguration.swift:52-64`, public under `#if DEBUG` only. SwiftPM compiles
    dependencies in the app's configuration, so every Debug build of an app has it, and the API
    surface differs between builds.
- **Impact:** contradicts "no accept-all mode reachable in release builds".
- **Fix:**
  - The core rejects the flag unless it is built with a test-only option (off in release
    artifacts).
  - Kotlin and Swift move the API behind `@RequiresOptIn` / `@_spi(Testing)`, or into test
    support.
  - **Unverified:** whether `extraConfiguration` can override `sip_verify_server`. It is
    appended after the generated keys, and libre's first-match behavior was not confirmed; the
    core should reject security keys in it either way.
- **Tags:** API, Behavior.

### B-11 Android: the camera is sent after an audio-only answer from the system UI
- **Location:** `Android/baresipkit-telecom/.../BaresipTelecomAdapter.kt:330-341` (stores
  `answerVideo`) and the push→INVITE answer path at `:466-473` (uses
  `PushCallLedger.sendsCamera(...)` and never reads `answerVideo`).
- **Description:** when Telecom answers a pushed call as audio-only before its INVITE arrives, the
  call is answered with the camera on if the push and the INVITE have video. Confirmed by
  reading.
- **Impact:** a privacy bug: the camera goes out against the user's choice.
- **Fix:** take `answerVideo.remove(uuid)` first in the `answerNow` branch.
- **Tags:** Behavior (bug fix).

### B-12 Android: the Telecom adapter's event loop can die
- **Location:** `BaresipTelecomAdapter.kt:156` (`engine.events.collect { handle(it) }`, no
  try/catch), `:497` (`call.ready.await().setActive()`, not guarded).
- **Description:** a throw from `ready.await()` ends the collector. That happens when `addCall`
  failed or the call scope was cancelled. From then on the adapter ignores every call until the
  process restarts. The awaits have no timeout either, so one slow `addCall` stalls all events.
- **Fix:** guard each event (rethrow only on cancellation of the adapter's scope), use the action
  timeout for every `ready` await, and run per-call waits in their own coroutines.
- **Tags:** Behavior (bug fix).

### B-13 Android: the camera can stay on after the preview left the screen
- **Location:** `Android/baresipkit-compose/.../BaresipCallVideo.kt:64-73,93-97`.
- **Description:** attach and detach are two unordered coroutines on `Dispatchers.Default`, so
  stop can run before start. An old preview's dispose can also stop a newer one.
- **Unverified** on a device; the race is visible in the code.
- **Fix:** one coroutine per effect, with `try { attach; awaitCancellation() } finally { detach }`
  and a token per preview.
- **Tags:** Behavior (bug fix).

### B-14 Release status, versions and licensing of the artifacts
- **Location:**
  - "Beta, no release yet" in `README.md:6,26`, `Docs/iOS.md:12,36`, `Docs/Android.md:9,33`,
    `Docs/Releasing.md`, `SECURITY.md:16`, DocC `BaresipKit.md:7` and `GettingStarted.md:14`.
  - `Android/gradle.properties:6` `VERSION_NAME=0.1.0-SNAPSHOT`.
  - `Core/src/bsk_internal.h:14` `BSK_VERSION_STRING "beta"`, used as the default User-Agent.
  - `CHANGELOG.md` has no `[1.0.0]` section.
  - The AAR ships no third-party license texts, and its POM declares only BSD-3-Clause, while
    `libbaresipkit.so` embeds OpenSSL (Apache-2.0), libre, baresip, Opus, libvpx and G.722.
  - `THIRD_PARTY_NOTICES.md` copyright lines for libre and baresip differ from upstream
    `LICENSE`, the Android sample's fonts are missing, and it says OpenSSL's NOTICE must ship
    while OpenSSL 3.5 has no NOTICE file.
- **Impact:** the release would contradict its own docs, and the Android artifacts would not meet
  the BSD and Apache-2.0 notice conditions.
- **Fix:** take one version from the release tag into Package metadata, `VERSION_NAME` and
  `BSK_VERSION_STRING`; write the changelog section; bundle the license texts in the AAR
  (`META-INF`); list all licenses in the POM; correct the notices.

### B-15 Distribution flow and release evidence
- **Location:**
  - `Package.swift:5-14`: empty URL, and the file-exists switch to a local binary.
  - `.github/workflows/release.yml`, `.github/workflows/release-android.yml`.
- **Description:**
  - The SwiftPM flow depends on the release workflow filling in URL and checksum. It already
    produced an unresolvable `1.0.0` once.
  - A stale local `Build/out` silently wins over the published binary.
  - No SBOM is generated.
  - Only the SwiftPM checksum is published: no SHA-256 list of all assets, no provenance.
  - The release binaries are rebuilt after CI, not the tested ones.
  - The Android release creates no tag and does not check the version against the tag or the
    changelog, and it releases to Maven Central at once.
- **Fix:**
  - CI checks that a tagged `Package.swift` has a URL and checksum.
  - The local override becomes explicit (an environment variable).
  - Generate SPDX or CycloneDX for the XCFramework (from `versions.env`, the patches and G.722)
    and for the AARs.
  - Publish `SHA256SUMS` and build-provenance attestations.
  - Build once and promote the tested artifact.
  - Stage the Maven Central deployment and check the version against the tag.

### B-16 Plausibly real phone numbers in API docs and tests
- **Location:**
  - API docs: `Sources/BaresipKit/Call/BaresipHandleStyle.swift:6`,
    `Sources/BaresipKit/BaresipKit.docc/CallKit.md:193`,
    `Android/baresipkit/src/main/kotlin/.../SipIdentity.kt:69`.
  - Tests: `Tests/BaresipKitTests/SystemCall/PushMatchTests.swift:58-59`,
    `Tests/BaresipKitTests/SwiftUI/MessagePeerTests.swift:16`, `PushCallLedgerTest.kt:73-74`,
    `BaresipRedialRequestTest.kt:26-27`, `BaresipPhoneControlTest.kt:242`.
- **Description:** they use numbers in Bosnia and Herzegovina's geographic and mobile formats.
  Whether they are assigned is **unverified**.
- **Fix:** use fictional ranges, for example `+1 555 0100`–`0199` or `+44 7700 900xxx`.

## Should fix

### API shape (all **API**; approval needed)
- **S-01 Errors carry non-errors.**
  - `BaresipError` (Swift and Kotlin) holds `Code.ok`, `isFailure` and `endReason`, so
    `.call(_, _, error)` returns an "error" for a call answered elsewhere or replaced.
  - Fix: move `endReason` into the call event payload and drop `ok` and `isFailure`.
- **S-02 Plumbing is public.**
  - Swift: `isEngineThread`, `abiVersion`, `capabilities`, `BaresipNetworkEvent.init`,
    `BaresipPhoneCall.refresh()`, `userPart(of:)`, `samePeer`, the duplicate typealiases in
    `BaresipKitVideo/BaresipVideo.swift`.
  - Kotlin: the same, plus `BaresipCameraSource` (a native pointer), `BaresipCameraHost.install`,
    `BaresipCertificates.split` returning `Pair`, `BaresipAudioRoute.of(int)`.
  - Fix: make them internal, or put them behind `@_spi` / `@RequiresOptIn`.
- **S-03 Delegate conformances are public API.**
  - The adapters conform to `CXProviderDelegate`, `ConversationManagerDelegate` and
    `PKPushRegistryDelegate` themselves, so clients can call `providerDidReset` and the rest.
  - Fix: move the conformances to private delegate objects.
- **S-04 Naming and argument order differ within and across the platforms.**
  - `hangup` vs `hangUp`.
  - `setHeld(_:uuid:)` vs `setOnHold(_:call:)`.
  - `ringtoneSound` vs `ringtoneName`.
  - `account` vs `accountID`.
  - The call argument comes first in some Kotlin functions and last in others.
  - `suspend()` / `resumeFromBackground()` next to `resume(call)`.
  - Boolean names that are not assertions.
  - Kotlin's `Dtmf`/`Tls` vs Swift's `DTMF`/`TLS` is correct for each language; document the
    mapping, because `Docs/Android.md:3` claims the names are identical.
- **S-05 Stringly-typed configuration.**
  - Module names, audio module and device names, `setCamera(_: String)`,
    `local: Bool` on `setVideoRenderer`, `BaresipPushTokens.platform` and `timeout: Int`,
    `pinnedSPKISHA256: [String]`.
  - Fix: decide which become types and which are marked as advanced or unstable.
- **S-06 `events` is a computed property with side effects.**
  - Swift: each access adds an unbounded subscriber.
  - Kotlin: `extraBufferCapacity = Int.MAX_VALUE`, and the flow never completes after `close()`.
  - Fix: a method with a buffering policy; complete the stream on close.
- **S-07 `BaresipPushTokens` names a legacy parameter format generically.**
  - The RFC 8599 parameters are not produced.
  - Fix: name the format, or make the encoding pluggable.
- **S-08 `BaresipCallController` is an open protocol/interface.**
  - Adding a requirement breaks external conformers, and mute observers cannot be removed.
  - Fix: document it as implemented by the SDK only, and add a removal token.
- **S-09 Kotlin consumers need Kotlin ≥ 2.3.**
  - The class metadata is 2.4, and coroutines 1.11 and stdlib 2.4.21 are forced on consumers.
  - Fix: set `apiVersion` / `languageVersion` and `coreLibrariesVersion` to a supported floor, and
    state the floor.
- **S-10 The Kotlin API is effectively Kotlin-only.**
  - Value classes and suspend functions give mangled JVM names.
  - Fix: state this in the docs (a Java facade is Later).

### Correctness and robustness
- **S-11 Random `instanceUUID` default on both platforms.**
  - The default is a new UUID at every launch, although the docs say it must be stable per
    install. That leaves stale Contact bindings and forked INVITEs.
  - Fix: make it required, or persist it. **API, Behavior.**
- **S-12 No deadline on the PushKit asynchronous handler.**
  - `BaresipPushKitAdapter.swift:253-264`: if the handler hangs, iOS kills the app and
    eventually stops VoIP pushes.
  - Fix: race it against a deadline and report the placeholder on timeout. **Behavior.**
- **S-13 The PushKit placeholder uses its own `CXProvider`.**
  - `BaresipPushKitAdapter.swift:316-330` creates a separate provider with an `"unknown"`
    handle; this was not checked on a device.
  - Fix: let the app's adapter report the placeholder.
- **S-14 Some continuations are resumed only by the system.**
  - `requestAndWait` and `placeCall` (both iOS adapters) hang if the system never calls
    `perform` (**unverified**).
  - Fix: add a safety deadline, and resume with a domain error instead of `CancellationError`
    on reset.
- **S-15 iOS audio interruptions and activation.**
  - A stale interruption "began" with reason `appWasSuspended` is not ignored
    (`BaresipAudioSessionController.swift:167-176`).
  - The adapters give the app no hook for `didActivate` / `didDeactivate`, so the controller's
    CallKit path is unreachable while an adapter is in use.
- **S-16 iOS video.**
  - The core never sets `rotationDegrees`, and `BaresipVideoView` ignores it, so landscape is
    sideways.
  - The front camera is mirrored at capture, so the remote side sees a mirrored picture
    (**unverified** on a device).
  - On iOS 16 there is no recovery from a failed `AVSampleBufferDisplayLayer` after
    backgrounding, and one main-actor `Task` is started per frame.
- **S-17 iOS `BaresipAppLifecycle` has no `deinit` cleanup.**
  - `willTerminate` blocks the main thread up to the timeout + 1 s.
- **S-18 Android engine lifecycle.**
  - `close()` races native getters on `handle` (use-after-free, `BaresipEngine.kt:85-90` vs
    `502-507`).
  - `close()` blocks up to 10 s.
  - Cancelling `makeCall`, `addAccount` or `sendMessage` leaks what the core created.
  - `runCatching` swallows `CancellationException` and real errors (`accounts()`,
    `activeCalls()`, `videoDevices()`).
- **S-19 Android Telecom.**
  - `end()` leaves a ghost Telecom call when `hangup` throws (`:260-262`).
  - The adapter and the lifecycle collectors subscribe asynchronously and can miss an incoming
    call.
  - `callerConfirmed` is computed but unused, so a caller-less push bound to any INVITE keeps
    the push's name.
- **S-20 Android audio.**
  - Focus loss and gain are handled in unordered coroutines.
  - On API < 31, SCO is not stopped in `deactivate()`, and SCO is marked up before
    `SCO_AUDIO_STATE_CONNECTED`.
  - `release()` keeps the scope alive.
- **S-21 Android camera.**
  - `onDisconnected` / `onError` close the camera silently.
  - Rotation uses the deprecated `defaultDisplay`.
- **S-22 Native input validation.**
  - JNI `cameraPush` does not check direct-buffer capacity against stride × height (an
    out-of-bounds read from public API, `bsk_jni_video.c:332-383`).
  - `mediacodec.c` trusts the decoder's crop rectangle and buffer sizes (`:226,373-376,504-539`).
  - `bskcamera.c` truncates strides to 16 bits.
  - JNI config readers continue after a pending exception, and do not delete local references in
    loops.
- **S-23 C threading.**
  - The log handler and the event handler share `cb_mtx`, so a `bsk_*` call from a log callback
    on a media thread can deadlock, and audio threads wait on the app's event handler.
  - Events are delivered re-entrantly, despite "one event at a time".
  - `bsk_*` calls from video frame callbacks can deadlock or free objects in use.
  - `bsk_engine_destroy` on the engine thread is a use-after-free, and C-ABI.md calls it
    "idempotent".
  - The `STOPPED` event arrives after libre closed, and `bsk_run` on the engine thread then runs
    against closed baresip.
  - `thread`, `state` and `g_engine` are shared without atomics, and there is no TSan job.
  - Fix: separate log lock, event queueing or documented re-entrancy, guards, atomics, a TSan
    CI job.
- **S-24 C API correctness.**
  - `BSK_EVENT_DIAGNOSTIC` is documented but never emitted.
  - `bsk_engine_suspend` is a no-op.
  - DTMF events have no direction.
  - `EOVERFLOW` and `ECANCELED` map to `BSK_ERR_INTERNAL`.
  - Session timer values below RFC 4028's 90 s minimum are accepted.
  - A negative cumulative loss gives garbage loss and MOS figures.
  - `bsk_capabilities` claims VideoToolbox on every platform.
  - `sip_transports` is never parsed, so plain `ws` stays enabled.

### Security and privacy
- **S-25 Media encryption defaults.**
  - Media is unencrypted by default, and SDES keys are allowed over UDP/TCP signaling.
  - Fix: document the default; warn about or reject SDES unless the transport is TLS or WSS.
    **Behavior** if rejected.
- **S-26 Logging defaults.**
  - A zeroed config logs at DEBUG (`BSK_LOG_DEBUG == 0`).
  - `BaresipOSLog` logs everything as `.public`, and redaction does not cover URIs, IPs, display
    names or custom auth headers.
  - Fix: default to INFO, use `.private` by default, document what is redacted.
    **API, Behavior.**
- **S-27 Credentials in Kotlin `toString()`.**
  - Data-class `toString` prints the account password, the TURN password and the push token.
  - Fix: redact them.
- **S-28 The password-wiping claim is false.**
  - C-ABI.md says passwords are wiped on release, but baresip frees `auth_pass` and `stun_pass`
    without wiping.
  - Fix: correct the doc or patch baresip.
- **S-29 `min_version` accepts any raw integer.**
  - The TLS minimum takes OpenSSL wire values, including TLS 1.0.
  - Fix: define TLS 1.2 and 1.3 constants and reject others.
- **S-30 Android manifests.**
  - The video library merges `CAMERA` into every app, and uses `android.hardware.camera` instead
    of `camera.any`.
  - The normal permissions the libraries need are not declared.
  - Consumer R8 rules are never exercised by a minified build, and one rule matches nothing.
- **S-31 Privacy manifest required-reason APIs.**
  - The libraries in the XCFramework were not checked for `mach_absolute_time`, `statfs` and
    similar (**unverified**, no macOS).
  - Fix: run `nm -u` per slice and update `PrivacyInfo.xcprivacy`.
- **S-32 Security and conduct contacts.**
  - `SECURITY.md` relies on GitHub private vulnerability reporting without a fallback, and
    whether reporting is enabled is **unverified**.
  - `CODE_OF_CONDUCT.md` sends conduct reports to the vulnerability form.
- **S-33 Dependency vulnerability check not performed.**
  - No network access to CVE/GHSA data here.
  - OpenSSL 3.5.9, baresip and libre 4.13.0, Opus 1.6.1, libvpx 1.15.2 and the Gradle
    dependencies must be checked before the release.

### Build, CI and tests
- **S-34 Builds are not reproducible.**
  - 116 (host) and 1 649 (Android) absolute build paths are embedded, and the OpenSSL build date
    is embedded too.
  - Fix: `-ffile-prefix-map`, `SOURCE_DATE_EPOCH`, `ZERO_AR_DATE`, a normalized zip.
- **S-35 Toolchains are not pinned.**
  - `macos-latest` with the default Xcode, and unpinned brew/apt lint and build tools.
  - The docs say "Xcode 16 or later", but CI never builds with 16.
  - The Gradle wrapper has no `distributionSha256Sum` or validation.
- **S-36 Lower bounds are not tested.**
  - The Android emulator runs API 34 only (minSdk 28), and iOS the newest simulator only
    (minimum 16).
- **S-37 Integration gaps against Docker Asterisk/coturn.** Missing:
  - video calls;
  - network change during a call;
  - registration failure and retry;
  - SRTP/DTLS-SRTP;
  - any run of the Swift or Kotlin layers against Asterisk.
- **S-38 The interop matrix is thin.**
  - Only Asterisk and coturn, while the README claims support for media relays.
  - `Docs/CompatibilityMatrix.md` cites v4.9.0 line numbers.
  - Fix: add FreeSWITCH and Kamailio with an RTP relay to Docker, or narrow the claims.
- **S-39 Fuzzing gaps.**
  - `bsk_reason_sip_cause` and trace redaction on whole SIP messages are not fuzzed.
  - `-max_len=512` never reaches the H.264 large-unit path, and no corpus is kept.
- **S-40 The iOS and Android module sets differ.**
  - iOS releases `default` (no VP8), Android `full` (VP8); README says "VP8 in the full module
    set on both".

### Code quality and docs
- **S-41 Comment policy.**
  - Six explanatory comment blocks in `Core/src` (`bsk_audio.c:41,74`, `bsk_call.c:260`,
    `bsk_call_ops.c:57`, `bsk_hold.c:6,66`) and eight lines in four Swift files.
  - The public C header has almost no API doc comments.
- **S-42 Stale docs.**
  - `Docs/C-ABI.md` "Proposed C ABI" with open points for 0.1/0.2.
  - `Docs/Limitations.md` "ABI 0.1".
  - `Docs/Building.md` lists no Android platform.
  - `Docs/Platforms.md:73-74` gives a wrong Maven group.
  - `Docs/Architecture.md:60` says frames arrive on media threads.
- **S-43 Missing guides.**
  - No `Docs/STABILITY.md`.
  - No DocC articles for TLS/certificates, ICE/TURN, threading and troubleshooting.
  - No Android guides for TLS and ICE/TURN.
  - Telecom and FCM have short recipes only, without Android 14+ full-screen-intent and
    foreground-service-type rules.
  - Dokka has no `reportUndocumented` / `failOnWarning`.
  - About 36 Kotlin public declarations lack KDoc.
  - README has no install snippet or minimal example.
- **S-44 Templates and labels are iOS-only.**
  - The issue templates ask for the iOS version only, and the PR template has no Android checks.
  - There is no labels configuration with `ios`, `android` and `core`.
- **S-45 Local repository settings point to the old name.**
  - The git remote is still `baresip-swift`; GitHub redirects to `baresipkit`, which the docs
    and POM use.
- **S-46 Sizes and timings are not measured.**
  - XCFramework slice sizes, engine cold start, registration time, push-to-incoming-call time,
    call setup time, and CPU/battery on a device are not measured.
  - Fix: record the binary sizes in CI and measure the timings on a device, or state them as not
    measured.

## Later (1.x backlog)

- **L-01 Duplicated logic across the two SDKs.** The push-to-INVITE ledger, SIP identity matching
  and the call bookkeeping exist in both Swift and Kotlin; they are candidates for the C facade.
- **L-02 Patches not yet upstream.** All 27 patches are "to be proposed". The memory and lifetime
  fixes (0015, 0016, 0019–0022) should be reported upstream first. The heavy patches (0024,
  0008, 0007, 0027) are the main maintenance risk. The verification recipe in
  `Patches/README.md` fails for stacked patches.
- **L-03 C leftovers.**
  - `make_op` orphans a call when context allocation fails.
  - An AVCC copy is made per frame in `mediacodec.c`.
  - `extra_config` is unvalidated.
  - SecTrust evaluates synchronously on the engine thread.
  - `bsk_engine_stop` invalidates accounts without events.
  - The `atoi` overflow.
  - Default-account selection after removal.
  - `BSK_EXPORT` uses `dllexport` for consumers.
  - Dead fields and prototypes.
- **L-04 Swift leftovers.**
  - Unknown C states map to `.failed`.
  - Files with more than one primary type.
  - Untyped `throws`.
  - Hard-coded English in the SDK UI.
  - Unbounded `releasedCalls`.
  - A `CIContext` per snapshot.
  - `fakevideo` in the default modules.
  - `BaresipTURNServer` is `Codable` with its password.
  - Plain `import` of the C modules (use `internal import`).
  - Tests do not mirror sources.
- **L-05 Kotlin leftovers.**
  - armeabi-v7a decision.
  - `-fvisibility=hidden` for `libbaresipkit.so`.
  - Dead code in `PushCallLedger`.
  - Per-pixel YUV rotation and per-frame allocations.
  - `load_methods` initialization.
  - Hard-coded English.
  - Uncancelled scopes and missing Cleaners.
  - `GLSurfaceView` pause/resume.
  - ktlint engine version and `max_line_length = 200`.
  - No Android Lint in CI.
  - `registerAppWithTelecom` on devices without Telecom (**unverified**).
- **L-06 CI hardening.**
  - No CodeQL or clang-tidy.
  - No Dependabot.
  - Cache keys ignore the toolchain.
  - The screenshots step is `continue-on-error`.
  - The trust test skips silently without network.
  - DoorStack clones without commit verification.
  - coturn is pinned by tag, not digest.
- **L-07 Private 10.x addresses in two Zvono tests**; prefer RFC 5737.
- **L-08 Process artifacts.**
  - `Docs/release/` names the review branch.
  - Commit trailers carry session URLs.
  - Decide whether `Docs/release/` stays in the tree after the release.

## Checked and found fine

- **Upstream sources:** pinned by tag and commit, verified before every build. No prebuilt
  third-party binaries.
- **CI actions:** pinned by SHA with minimal permissions.
- **Release workflow:** waits for green CI, uploads to a draft, pushes the tag atomically.
- **C ABI isolation:** no platform, libre or OpenSSL types in `baresip_kit.h`, and no `bsk_*` or
  raw pointers in the public Swift API. JNI and native handles stay internal on Android, except
  `BaresipCameraSource` (S-02).
- **Marshalling and callbacks:**
  - Calls are marshalled through an op on the caller's stack, which stop cancels.
  - Size-prefixed configuration copying is correct.
  - Video sink replacement waits for frames in flight.
  - Hangup and remove are deferred inside event handlers.
- **Input checks:** account and URI input is checked for injection; the Contact parameter
  encoding, Reason and SIP trace parsers stay within bounds.
- **TLS:**
  - Minimum 1.2 by default, and verification on by default.
  - Pins without verification are rejected.
  - TURN-over-TLS and WSS verify the host.
- **Redaction:** covers the digest response, passwords, push tokens, SDES keys, ICE passwords,
  DTMF and MESSAGE bodies.
- **Robustness:** no force unwraps, `try!`, `as!` or `fatalError` in Swift sources, and no `!!` in
  Kotlin library sources.
- **Continuations:** resumed exactly once on every inspected path.
- **Docs:** every public Swift declaration has a doc comment, and DocC builds with warnings as
  errors in CI.
- **JNI references and threads:**
  - Global references are released on every path.
  - Native threads attach as daemons and detach through a pthread key.
  - Callbacks use local frames and clear exceptions.
- **Android native libraries:**
  - Both ABIs have 16 KB-aligned `LOAD` segments.
  - The NDK version matches the pins.
  - The POM metadata is complete, signing is configured, and the sample is not published.
- **Samples:** both build without private configuration, contain no real hosts or tokens, and
  have sound manifests and privacy manifests.
- **Full-history scan:** no tokens, real keys or real hostnames; IP addresses are documentation
  ranges, loopback or generic private defaults.

## Proposed fix plan (after approval)

Ordered by severity. Each line is one Conventional Commit or a small series, with docs, API
baselines and `CHANGELOG.md` updated in the same commit. Items marked API or Behavior wait for
explicit approval.

1. **Decisions D1–D6.** Then B-01 (tag scheme and workflow) and B-02 (local refs, fresh clone).
   No code change.
2. **B-04:** pin check against the validated chain, with a regression test (`fix(core)`).
3. **B-11, B-12, B-13:** Android Telecom answer-video, event-loop guard and preview lifecycle,
   with JVM tests (`fix(android)`).
4. **B-10:** accept-all TLS out of release builds (`fix(core)`, `refactor(api)`; API).
5. **B-03, B-16:** neutrality and fictional numbers (`docs`, `test`).
6. **B-07 and the D3 policy:** `Docs/STABILITY.md` (`docs`).
7. **B-05:** per D2, either documentation or growable structs (`docs` or `feat(core)!`).
8. **B-08, B-09, S-01–S-11:** the pre-freeze API pass on both platforms. One commit per type
   group, each with its own approval (`refactor(api)!`).
9. **B-06:** `explicitApi()`, Kotlin ABI dumps, Swift API digests, CI checks (`ci`, `build`).
10. **B-14, B-15:** version from the tag, license texts in the AAR, notices, SBOM, SHA256SUMS,
    provenance, release workflow checks (`build`, `ci`, `docs`).
11. **Robustness:** S-12–S-24 (`fix(...)`).
12. **Security and privacy:** S-25–S-33. The dependency check needs network access.
13. **CI and tests:** S-34–S-40.
14. **Docs and community:** S-41–S-46.
15. **Release candidate:** `RELEASE_CHECKLIST.md`, release notes draft, `V1_REPORT.md`.
