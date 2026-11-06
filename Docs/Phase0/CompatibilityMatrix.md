# BaresipKit feature compatibility matrix

Pinned sources: libre v4.9.0 (`e11a4c5`), baresip v4.9.0 (`c06e367`). File references are relative to those checkouts. Status vocabulary, as requested:

- **as-is** — supported by libre/baresip core without extra code
- **module** — supported by an existing baresip module that only has to be compiled in
- **facade** — needs code in `BaresipKitCore` (Layer 2) or a BaresipKit-owned module, no upstream change
- **patch** — needs a baresip/libre patch (kept in `Patches/`, upstreamable)
- **not feasible** — cannot be provided with baresip as the engine

Everything below was verified by reading the pinned sources; items marked "host-verified" were additionally exercised on Linux in this phase.

## 1. Runtime, threading, OS abstraction

| Requirement | Status | Evidence / notes |
|---|---|---|
| Portable OS abstraction | as-is | libre `src/main`, `src/net`, `src/thread/posix.c`, `src/dns/darwin/srv.c` for iOS (`CMakeLists.txt:592`). iOS has no C11 `threads.h`, so the pthread fallback in `re_thread.h` is used; the toolchain forces `HAVE_THREADS=OFF`. |
| libre main loop threading model | as-is + facade | One `re_main()` loop per thread (`re_main.h:53-71`: `re_alloc`, `re_thread_attach`, `re_thread_enter/leave`, `re_thread_check`). All libre/baresip objects are owned by the loop thread. `re_thread_async()` provides worker threads with completion on the loop thread. `mqueue` is the thread-safe wake-up primitive. The facade runs the loop on a dedicated thread and marshals every API call onto it (see `C-ABI.md`). |
| Safe, idempotent shutdown | facade | `ua_stop_all()`, `ua_close()`, `baresip_close()`, `mod_close()`, `libre_close()` in that order (`src/main.c:335-361`). The facade enforces the order and waits for `BEVENT_SHUTDOWN`/`BEVENT_EXIT`. `mem_debug()` and `tmr_debug()` can be enabled in debug builds to assert zero leaked handles. |
| Static module set (no dlopen on iOS) | as-is | `-DSTATIC=ON` generates `src/static.c` with an export table (`CMakeLists.txt:201-212`); module OBJECT libraries are folded into `libbaresip.a` (host-verified: 20 modules, one archive). |
| Native log routing | facade | `log_register_handler()` / `log_enable_stdout(false)` in `src/log.c`; libre `dbg_handler_set()`. SIP trace via `uag_enable_sip_trace()` goes through the same handler. |

## 2. Audio

| Requirement | Status | Evidence / notes |
|---|---|---|
| Audio driver on iOS | module | `modules/audiounit` (`audiounit.c`, `player.c`, `recorder.c`). On iOS it selects `kAudioUnitSubType_VoiceProcessingIO` (`audiounit.c:138`), which gives hardware echo cancellation, noise suppression and AGC. `CMakeLists.txt` gates on the **host** being Darwin, so cross-builds from macOS work unpatched. |
| Coexistence with an app-owned `AVAudioSession` | as-is (good) + facade | The pinned module never touches `AVAudioSession` (verified: no reference in `modules/audiounit/*`). `sess.c` only keeps an interruption list. The facade exposes `bsk_engine_audio_session_activated/deactivated()` and starts/stops the audio source and player (`audio_set_source`/`audio_set_player`, `baresip.h:1453-1454`) only between those calls. Nothing in the core configures the session. |
| Microphone mute | as-is | `audio_mute()` / `audio_ismuted()` (`baresip.h:1447-1448`). |
| Per-direction audio control | as-is | `call_set_audio_ldir()` + `call_modify()` (`call.c:1467`), `call_set_media_direction()` (`call.c:3299`). |
| Route changes (speaker/earpiece/BT/wired) | facade (app side) | Routes are an `AVAudioSession` concern and stay in `BaresipKitAudio`. The core only needs `bsk_engine_audio_route_changed()` to restart the AudioUnit when the hardware sample rate changes (`recorder.c:280-301` reads the HW rate on iOS). |
| Interruptions | module + facade | `audiosess_interrupt()` (`sess.c`) is the hook; nothing calls it on iOS today. The facade calls it from `bsk_engine_audio_interruption()`. |
| Software AEC / NS / AGC | module (optional) | `modules/webrtc_aec` needs the external WebRTC AEC library; not planned for iOS because VoiceProcessingIO already provides it. Configurable through `bsk_audio_config.voice_processing` (switch to `kAudioUnitSubType_RemoteIO` needs a 3-line change in `audiounit.c`, candidate patch). |
| Adaptive jitter buffer | as-is | `JBUF_OFF/FIXED/ADAPTIVE` (`baresip.h:77-79`), config `audio_jitter_buffer_type/_delay/_ms` (`config.c`). |
| External audio input/output | module | Any `ausrc`/`auplay` implementation can be registered (`ausrc_register`, `auplay_register`, `baresip.h:631,671`); `aubridge` and `aufile` exist. Exposed in a later ABI revision, not in Phase 0. |
| Codecs: Opus | module | `modules/opus` (external libopus, pinned v1.6.1, host-verified). |
| Codecs: G.711 | module | `modules/g711` (built-in, host-verified). |
| Codecs: G.722 | module (external) | `modules/g722` needs spandsp, `modules/libg722` needs libg722. Not in the default set; add on request. |
| DTMF RFC 4733 | as-is | `audio_send_digit()` via `telev` (`re_telev.h`, `TELEV_PTIME=50`). |
| DTMF SIP INFO | as-is | `send_dtmf_info()` with `application/dtmf-relay` (`call.c:2707`). Mode per account: `account_set_dtmfmode()` with `DTMFMODE_RTP_EVENT`, `SIP_INFO`, `AUTO` (`baresip.h:62-65`). `AUTO` picks RTP when the peer negotiated telephone-event, else INFO (`call.c:1780-1796`), so the transport actually used per call is known. |
| Configurable DTMF duration / inter-digit gap | facade | baresip sends one digit at a time; sequences, duration and gap are implemented in the facade with a timer on the engine thread. |
| In-band DTMF detection | module | `modules/in_band_dtmf`. |

## 3. Video

| Requirement | Status | Evidence / notes |
|---|---|---|
| Camera capture on iOS | implemented (`Core/src/apple/bskcapture.m`, compiled for device and simulator in CI; needs a physical device to exercise) + patches 0002/0003 for upstream avcapture | `modules/avcapture/avcapture.m` exists but: CMake gates on `CMAKE_SYSTEM_NAME MATCHES "Darwin"` (iOS cross-builds set `iOS`) → `Patches/0002`; it references `AVCaptureScreenInput` (macOS-only, fails to compile against the iOS SDK), uses manual reference counting, has no orientation, frame-rate or pixel-format control, and copies nothing but also offers no `CVPixelBuffer` pass-through. BaresipKit will ship its own `vidsrc` module in `BaresipKitVideo` (`vidsrc_register`, `baresip.h:1185`) that keeps `CVPixelBuffer`s zero-copy to the encoder. The upstream patch is still proposed so plain baresip builds for iOS. |
| Remote rendering | implemented (`Core/src/bsk_video.c`, host-verified with VP8) | `vidisp_register()` (`baresip.h:1230`) with `vidisp_disp_h(st, title, const struct vidframe*, timestamp)`. The facade registers a `vidisp` that forwards frames to `bsk_video_sink` callbacks; `BaresipKitVideo` wraps them into `CVPixelBuffer`s for a `AVSampleBufferDisplayLayer`/Metal view. |
| Local preview before answer | implemented (host-verified with fakevideo) | `video_set_source()` / `vidsrc_alloc()` can run without a call; the facade exposes `bsk_video_preview_start()`. |
| Front/back switching | as-is + facade | `video_vidsrc_set_device()` (`video.c:1708`), `vidsrc_update_h`. |
| Orientation / resolution / frame rate | facade | `video_size`, `video_fps`, `video_bitrate` config keys; rotation metadata is handled in the BaresipKit capture module (upstream `avcapture` has none). |
| H.264 encode/decode | implemented and CI-verified on macOS (`Core/src/apple/vidtoolbox.c`; two-process H.264 call at 640x480 delivers remote frames on both sides) | **No VideoToolbox module exists upstream.** The only H.264 path is `modules/avcodec` (FFmpeg, with a `videotoolbox` hwaccel hint in `config.c:791`). Linking FFmpeg into an iOS app is not acceptable for size and licensing. BaresipKit will add a `vidtoolbox` codec module implementing `struct vidcodec` (`baresip.h:1342-1355`) with `VTCompressionSession`/`VTDecompressionSession`, reusing libre's packetizer and parser (`re_h264.h`: `h264_packetize`, `h264_nal_send`, `h264_stap_*`, `h264_sps_decode`). SDP `packetization-mode=1` and `profile-level-id` handling is copied from `modules/avcodec/sdp.c`. Software fallback: none on iOS (VideoToolbox is always present); the module reports `BSK_ERR_UNSUPPORTED` if the session cannot be created. |
| VP8 | module (external) | `modules/vp8` with libvpx (cross-build target `arm64-darwin20-gcc`). Optional `MODULE_SET=full`. |
| RTCP feedback NACK / PLI / FIR | as-is | `video.c:30-32` (`PICUP_INTERVAL`, `NACK_BLPSZ`), `rtcp_nack_handler` (`video.c:911`), `send_fir(strm, nack_pli)` (`video.c:699`); `video_req_keyframe()` (`video.c:1959`). |
| Bitrate adaptation | partial | Fixed `video_bitrate`/`video_sendrate` with a token-bucket pacer (`video.c:521-575`). No REMB/TWCC-based adaptation. Reported as **not supported**; the facade can lower the encoder bitrate on RTCP loss reports (facade logic, later phase). |
| Decoded-frame callbacks + native view | facade | Covered by `bsk_video_sink` and `BaresipKitVideo`. |
| Early video (preview before answering) | as-is | `ANSWERMODE_EARLY_VIDEO`, `call_early_video_available()` (`call.c:2744`), `call_progress_dir()` (`call.c:1268`). |

## 4. SIP, accounts, registration

| Requirement | Status | Evidence / notes |
|---|---|---|
| Multiple accounts, default account | as-is | `ua_alloc()` per account, `uag_list()`, `uag_raise()`/`ua_raise()` for the default (`baresip.h:1010,1190`). |
| UDP / TCP / TLS | as-is | `ua_init(software, udp, tcp, tls)`; account `;transport=` parameter. |
| WSS | as-is | `sip_transp_add_websock()` (`re_sip.h:316`), wired in `uag.c:420-460` with its own TLS context. Enable with `uag_enable_transport(SIP_TRANSP_WSS, true)`. |
| Separate SIP user and auth user | as-is | `;auth_user=` / `account_set_auth_user()` (`account.c:686`). |
| Digest MD5 and SHA-256 | as-is | `re/src/httpauth/digest.c:78,1121-1127` handles `SHA-256` and `SHA-256-sess`. |
| Configurable expiry, refresh | as-is | `;regint=`, `;rwait=` (5–95 % of expiry), `account_set_regint()`. |
| Retry with backoff | as-is | libre `failwait()` exponential backoff 30 s … 1800 s with jitter (`sipreg/reg.c:102`). Retry bounds exposed via facade by re-registering on `BEVENT_REGISTER_FAIL` with the app-configured policy. |
| Typed registration states / failure reasons | facade | From `BEVENT_REGISTERING/REGISTER_OK/REGISTER_FAIL/UNREGISTERING` plus `bevent_get_msg()` (status code, reason phrase). |
| RFC 5626 outbound, keep-alive | as-is | `;sipnat=outbound` + instance UUID adds `reg-id`, `+sip.instance`, `Supported: outbound, path` (`ua.c:118-150`, `sipreg/reg.c:319-343`); keep-alives start when the registrar answers with `Require: outbound` (`start_outbound`, `sip_keepalive_start`). Without server-side outbound there is no CRLF keep-alive in baresip → facade can call `sip_keepalive_start()` from the REGISTER_OK message (facade item). |
| Keychain-friendly credentials, never logged | facade | Credentials go through `account_set_auth_pass()` only; the facade never logs the account line and redacts `Authorization`/`Proxy-Authorization` and `pn-tok` in the SIP trace. |
| Custom Contact parameters (push) | patch (small) | libre supports URI params via `sipreg_set_contact_params()` (`re_sipreg.h:30`) and header params via the `params` argument; baresip exposes neither. `Patches/0001` adds `account_set_contact_params()`, `ua_set_contact_params()` and wires them into `reg_register()`. **Host-verified** end to end, see `ContactParameterProof.md`. |
| Custom SIP headers | as-is | `ua_set_custom_hdrs`/`custom_hdrs_add()` (`baresip.h:334`), applied to REGISTER and INVITE. |

## 5. Calls

| Requirement | Status | Evidence / notes |
|---|---|---|
| Outgoing / incoming / answer / reject with code / hangup / cancel | as-is | `ua_connect()`, `ua_answer()`, `ua_hangup(ua, call, scode, reason)` (`baresip.h:955-968`). Cancel is `ua_hangup` on an outgoing call. |
| Stable call identifiers | as-is | `call_id()` returns the SIP Call-ID (`call.c:1553`); the facade maps it to a `bsk_call_id` integer. |
| Caller ID / display name / remote URI | as-is | `call_peeruri()`, `call_peername()`, `call_diverteruri()`. |
| Typed call states | facade | baresip states are `IDLE, INCOMING, OUTGOING, RINGING, EARLY, ESTABLISHED, TERMINATED, TRANSFER` (`baresip.h:191-199`). The 14 requested states are derived in the facade from these plus `BEVENT_CALL_HOLD/RESUME`, `call_is_onhold()`, `BEVENT_CALL_RTPESTAB`, `BEVENT_CALL_LOCAL_SDP/REMOTE_SDP` and the hold round-trip. |
| Early media (183 with SDP) | as-is | `call_progress()` / `call_progress_dir()`, `BEVENT_CALL_PROGRESS`, `sipsess_progress`. |
| Multiple calls, swapping | as-is | `call_max_calls`, `uag_hold_others()` (`uag.c:81`), `uag_hold_resume()`, `call_set_current()`. |
| Typed SIP reason mapping | facade | `call_scode()` + `bevent_get_text()`; `Reason` header available from `bevent_get_msg()`. |
| Blind transfer (REFER) | as-is | `call_transfer()` (`call.c:2987`), `BEVENT_CALL_TRANSFER(_FAILED)`. |
| Attended transfer | as-is | `call_replace_transfer()` (`call.c:3027`) sends REFER with `Replaces`. Supported. |

## 6. Hold / resume

| Requirement | Status | Evidence / notes |
|---|---|---|
| Local hold / resume with correct SDP direction | as-is | `call_hold()` → `stream_hold()` → `call_modify()` (re-INVITE or UPDATE, `call.c:1440-1457`, `call.c:1105`). Directions `sendonly/recvonly/inactive` handled in `stream.c`. |
| Remote hold detection | as-is | `BEVENT_CALL_HOLD` / `BEVENT_CALL_RESUME` emitted from the re-INVITE handler (`call.c:1845-1864`). |
| Hold one call while another is active | as-is | `uag_hold_others()`. |
| Keyframe after resume | as-is + facade | `video_req_keyframe()` after `BEVENT_CALL_RESUME`/local resume; facade calls it automatically and emits `BSK_MEDIA_KEYFRAME_REQUESTED`. |
| Verify ICE pair / RTP flow after resume | facade | `stream_rtcp_stats()`, `rtp_timeout` (`stream.c:1073`) and `BEVENT_CALL_RTPESTAB`; ICE pair via `icem_selected_lcand/rcand()`. Explicit test case planned for Phase 1 (TURN relay + video). |

## 7. NAT traversal and connectivity

| Requirement | Status | Evidence / notes |
|---|---|---|
| ICE | module | `modules/ice` (full ICE, RFC 8445 via libre `src/ice`). |
| STUN | module | `modules/stun`, `;stunserver=` account param. |
| TURN over UDP | module + patch 0006, CI-verified | `modules/ice/ice.c:232-258` (`turnc_alloc(... IPPROTO_UDP ...)`). Verified against coturn with the relay-only ICE policy (`ice_relay_only`): relay candidate selected, RTP in both directions. Patch 0006 fixes silent calls when optional SRTP is declined and ICE completes after the answer. |
| TURN over TCP / TLS | patch 0007 | The ICE module allocated relayed candidates over UDP only. `Patches/0007` adds TURN over TCP and TLS (`turns:`) inside ICE with a relay-only policy for that session; the integration job runs a relay call over each of UDP, TCP and TLS against coturn. |
| ICE restart | patch 0008 | Upstream `modules/ice/ice.c` has no ufrag regeneration; a network change only re-INVITEd with the old candidates. `Patches/0008` adds an mnat restart hook: new credentials, re-gathering and a re-INVITE after gathering, plus answerer-side restart on a new remote `ice-ufrag`. Tested baresip↔baresip (two-process ICE call) and against Asterisk through TURN over UDP, TCP and TLS. |
| Trickle ICE | not supported | libre has a `trice` library but baresip's `ice` module uses full candidate exchange in SDP. Documented as unsupported. |
| ICE disabled, symmetric RTP / latching | as-is | Omit `;medianat=`; baresip learns the remote address from incoming RTP (`stream.c` / `rtprecv.c` latching). |
| Direct vs relay path visible | patch (implemented) | `Patches/0005-baresip-ice-module-events.patch` emits ICE module events (gathering, checking, connected with candidate types and addresses, failed); the facade maps them to `BSK_EVENT_ICE` and `bsk_call_statistics`. Host-verified with host candidates. |
| Network change detection | module (desktop) / facade (iOS) | `modules/netroam` polls interface addresses (netlink only on Linux). On iOS the app has `NWPathMonitor`; the facade exposes `bsk_engine_network_changed()` which calls `uag_reset_transp(true, true)`. |
| IPv4/IPv6 dual stack, NAT64 | as-is | `net_af`, `sip_listen` per family; `dns_getaddrinfo` uses the system resolver, which on iOS performs NAT64 synthesis (`src/dns/darwin/srv.c` for SRV). |
| Timeout callbacks, ICE state | implemented | ICE state from the module events above; RTP timeout from `rtp_timeout` (30 s). |

## 8. Security

| Requirement | Status | Evidence / notes |
|---|---|---|
| TLS 1.2/1.3, verification on by default | as-is | `tls.c:214-237` sets a minimum of TLS 1.2; `sip_verify_server` defaults to on; `tls_set_verify_server()` enforces hostname matching (`transp.c:875`). `tls_set_min_proto_version()` available. |
| Private CA | as-is | `tls_add_capem()` (in memory, no file needed on iOS), `tls_add_cafile_path()`. |
| Custom trust callback / pinning | patch (implemented) | `Patches/0004-re-tls-verify-server-handler.patch` adds `tls_set_verify_server_handler()`; `Core/src/bsk_tls.c` implements SPKI SHA-256 pinning on top of it. Host-verified: private CA in memory, correct pin accepted, wrong pin and missing CA rejected with `BSK_ERR_TLS`. |
| No implicit accept-all | as-is | `tls_disable_verify_server()` exists but is only called when `sip_verify_server no` is configured. The facade exposes it only as `bsk_tls_config.verify_server=false` behind `BSK_ALLOW_INSECURE_TLS`, compiled out of release builds. |
| Cipher configuration | as-is | `tls_set_ciphers()`. |
| SRTP (SDES) | module | `modules/srtp`: `AES_CM_128_HMAC_SHA1_80/32`, `AEAD_AES_128_GCM`, `AEAD_AES_256_GCM` (`srtp.c:59-96`); `;mediaenc=srtp` optional, `srtp-mand` mandatory, `srtp-mandf` mandatory+forced. |
| DTLS-SRTP | module | `modules/dtls_srtp` (needs OpenSSL, `CMakeLists.txt`). |
| ZRTP | module (external, capability check only) | `modules/gzrtp` requires libzrtpcpp. Not planned. |
| Sensitive data out of logs | facade | Redaction layer in the log handler. |

## 9. Diagnostics

| Requirement | Status | Evidence / notes |
|---|---|---|
| Packet loss, jitter, RTT, bitrate | as-is | `stream_rtcp_stats()` (`baresip.h:1541`), `stream_metric_get_*` (`baresip.h:1544-1553`), `struct jbuf_stat` (`baresip.h:1588-1601`), `BEVENT_CALL_RTCP`. |
| MOS estimate | facade | Not provided by baresip; the facade computes an E-model style estimate from loss, jitter and RTT (documented as an estimate). |
| Codec negotiation, selected pair, audio route | facade | `video_codec()`, `audio` codec via `sdp_media_rformat`, ICE selected pair, route from `BaresipKitAudio`. |
| Timings | facade | `call_setup_duration()`, `call_duration()` (`call.c:2770-2786`), registration timing measured around REGISTER events. |
| Crash-safe logging | facade | Fixed-size event buffers in `bsk_event`, no allocation in the log path. |

## 10. Push and mobile lifecycle

| Requirement | Status | Evidence / notes |
|---|---|---|
| `prepareForPushWakeUp()` → fast registration | facade | Engine restart is `libre_init` → `baresip_init` → `ua_init` → `ua_alloc` → `ua_register` (≈ tens of ms on the host); registration latency is dominated by the network round trip. Measured in Phase 1 on device. |
| Incoming-call event as early as possible | as-is | `BEVENT_CALL_INCOMING` is emitted when the INVITE is accepted by `ua.c` before any media is set up. |
| Answer-before-INVITE (CallKit) | facade | Pending answer stored per expected Call-ID / caller; `BaresipKitCallKit` reconciles. |

## Summary of upstream changes needed

| # | Target | Size | Purpose | Status |
|---|---|---|---|---|
| 0001 | baresip | ~100 lines | Contact URI parameters API | written, host-verified |
| 0002 | baresip | 1 line | avcapture CMake gate for iOS | written |
| 0003 | baresip | ~50 lines | avcapture iOS guards for macOS-only API | written, macOS-verified |
| 0004 | libre | ~80 lines | client-side server-certificate verify hook (pinning) | written, host-verified |
| 0005 | baresip | ~60 lines | ICE module events (state, selected pair) | written, host-verified |
| 0007 | baresip | ~200 lines | TURN over TCP/TLS inside the ICE module | written, CI integration stage |
| 0008 | baresip | ~330 lines | ICE restart on network change and on remote ufrag change | written, CI two-process and integration stages |
| — | libre | 2 lines | export `HAVE_UNIXSOCK` in the CMake package so consumers get the same `struct sa` layout (found during the proof build) | candidate |

New BaresipKit-owned modules (no upstream change): `vidtoolbox` (H.264 via VideoToolbox), `bskcapture` (AVFoundation camera with `CVPixelBuffer` pass-through), `bskdisplay` (frame sink).
