# Proposed C ABI (Layer 2, `BaresipKitCore`)

Header: `Core/include/baresip_kit.h`. The header compiles as C11 and C++17 with `-Wall -Wextra -pedantic` and contains no libre or baresip types, so a Kotlin/JNI binding can use it unchanged.

## Design rules

1. **Opaque engine, integer handles.** `bsk_engine` is opaque. Accounts and calls are `uint64_t` ids that are never reused within an engine lifetime; `BSK_ID_NONE` (0) is invalid. Handles stay valid until the matching `BSK_EVENT_CALL_STATE` with `BSK_CALL_RELEASED` or `bsk_account_remove()` returns.
2. **Plain C only.** Enums are explicit integers. Structs contain only scalars, fixed-size char arrays and pointers to caller-owned strings or arrays. No bitfields, no callbacks inside config structs except the video sink.
3. **Caller owns inputs, engine copies.** Every `const char *` and array passed into a `bsk_*` function is copied before the call returns. The caller may free it immediately. Passwords are copied into memory that is wiped on release.
4. **Engine owns outputs.** `bsk_event` and everything it points to are valid only for the duration of the callback. Getter functions (`bsk_call_get_info`, `bsk_call_get_statistics`) fill caller-provided fixed-size structs; list functions take a caller buffer and return the required count so the caller can size it (`bsk_call_list`, `bsk_video_list_devices`, `bsk_capabilities`).
5. **Errors.** Every mutating function returns `bsk_status`. An optional `bsk_error *err` receives the system `errno`, the SIP status and reason phrase (for `BSK_ERR_SIP`), and a short message. Messages never contain credentials or full push tokens. `bsk_status_string()` gives a stable English name per code.
6. **ABI versioning.** `bsk_abi_version()` returns `(major << 16) | minor` (currently 0.12). The structs that may grow, `bsk_engine_config` and `bsk_account_config`, start with `uint32_t size`; initialise them with `BSK_ENGINE_CONFIG_INIT` / `BSK_ACCOUNT_CONFIG_INIT` (or set `size = sizeof(...)`). The core copies `min(size, sizeof)` bytes into a zeroed struct, so a caller built against an older header gets defaults for newer fields and a caller built against a newer header has unknown trailing fields ignored. `size == 0` is accepted and treated as the current size.

## Threading model

- `bsk_engine_start()` creates **one engine thread** that runs libre's `re_main()`. All libre and baresip objects live on that thread.
- Every `bsk_*` function is thread-safe and may be called from any thread. Internally the call is posted to the engine thread through a libre `mqueue` and the calling thread blocks until it has executed; the return value is the result from the engine thread. Blocking is bounded by the work itself (no network round trips happen inside API calls, except `bsk_engine_stop()` which has an explicit timeout).
- Calling a `bsk_*` function **from inside an event or log callback is allowed**: the facade detects `bsk_engine_is_engine_thread()` and executes directly, so no deadlock. Two requests are carried out only after the callback has returned, because baresip is still using the objects they destroy: `bsk_call_hangup`/`bsk_call_reject` and `bsk_account_remove`. They return `BSK_OK` at once. A call that is already ending (`ENDED`, `FAILED`) answers further requests with `BSK_ERR_NOT_FOUND`. `bsk_engine_start` and `bsk_engine_stop` are refused on the engine thread.
- `bsk_event_handler` is invoked **only on the engine thread**, one event at a time, in order; this includes `BSK_ENGINE_STOPPED`, which is the last event before the thread ends. The handler must return quickly and must not block on the caller's own locks that are also held while calling into `bsk_*` from another thread.
- `bsk_log_handler` may be invoked from the engine thread and from media threads (audio I/O callbacks, video capture queue). It is called with a complete line and length and must be signal-safe-ish: no allocation requirement is placed on the caller, the facade passes stack buffers.
- **Video frames.** `bsk_video_sink.on_frame` is called on the thread that produced the frame: camera frames (the local sink and the preview) on the capture queue, remote frames on the engine thread, because baresip decodes video where it receives RTP. A sink must therefore return quickly and hand slow work to its own queue; a slow remote sink delays SIP timers and every `bsk_*` call. Frames are valid only during the callback; `native_buffer` is a retained `CVPixelBufferRef` on Apple platforms which the sink may retain further. `bsk_call_set_video_sink`, `bsk_video_preview_stop` and the release of a call return only after running frame callbacks of the old sink have finished, so the sink's `user` pointer may be freed right after. A frame callback must not wait for another thread that calls into the engine. Audio I/O stays inside the AudioUnit module and is not exposed in this revision.
- **One running engine.** Several engines may exist, but only one may run per process, because baresip keeps global state; `bsk_engine_start` returns `BSK_ERR_BUSY` while another engine runs.
- `bsk_engine_destroy()` must not be called from the engine thread. It stops the engine if needed, joins the thread and releases all handles; it is idempotent.

## Mapping to baresip

| ABI | baresip / libre |
|---|---|
| `bsk_engine_create/start` (event handler via `bsk_engine_set_event_handler`, modules via `bsk_engine_config.modules`) | `libre_init`, `conf_configure_buf`, `baresip_init`, `ua_init`, static `module_load`, `bevent_register`, `re_main` on the engine thread |
| `bsk_engine_stop` | hang up every call, `ua_stop_all(false)` → `BEVENT_SHUTDOWN`, then `ua_close`, `baresip_close`, `mod_close`, `libre_close` |
| `bsk_engine_network_changed` | reload the local addresses (`net_flush_addresses`, `net_if_apply`), `net_dns_refresh`, `uag_reset_transp(reregister, update_calls)`; the TLS settings are applied to a TLS context that did not exist at start |
| incoming INVITE | `call_accept no`, so `BEVENT_SIPSESS_CONN` reaches the facade, which reads `Replaces` and calls `ua_accept()` |
| `bsk_engine_audio_session_*` | start/stop `ausrc`/`auplay` of the active call via `audio_set_source/player`; `audiosess_interrupt()` |
| `bsk_account_add` | `ua_alloc()` with a generated account line; `account_set_*` setters for credentials, `account_set_contact_params()` (patch 0001) |
| `bsk_account_set_contact_params` | `bsk_contact_params_encode()` validation → `ua_set_contact_params()` (patch 0001) |
| `bsk_call_make` | `ua_connect_dir()` |
| `bsk_call_answer/progress/reject/hangup` | `ua_answer()`, `call_progress_dir()`, `ua_hangup(ua, call, code, reason)` |
| `bsk_call_hold` | `call_hold()` on an established call; while another offer is in progress the request is kept and sent when that offer is done; a rejected re-INVITE is reported as the previous state with an error; `bsk_call_set_active` → `uag_hold_others()` + `call_set_current()`. With `hold_music_path` the held call's source becomes BaresipKit's `bskhold` module (the WAV file in a loop, resampled to the call) and `stream_set_hold_send()` (patch 0023) lets it through; on resume the microphone comes back before sending is closed again |
| `bsk_call_send_dtmf` | `call_send_digit()` per digit with timers for duration and gap |
| `bsk_call_set_microphone_muted` | `audio_mute()` |
| `bsk_call_set_audio/video_direction` | `call_set_audio_ldir()`/`call_set_video_dir()` + `call_modify()` |
| `bsk_call_request_keyframe` | `video_req_keyframe()` |
| `bsk_call_transfer` | `call_transfer()` |
| `bsk_call_get_statistics` | `stream_rtcp_stats()`, `stream_metric_get_*`, `icem_selected_*`, jitter buffer stats |
| `bsk_call_set_video_sink` / `bsk_video_preview_*` | BaresipKit `vidisp` and `vidsrc` modules |

## Event delivery guarantees

- `BSK_EVENT_CALL_INCOMING` is emitted from `BEVENT_CALL_INCOMING` before any media is allocated.
- Every `BSK_EVENT_CALL_STATE` with `ENDED` or `FAILED` is followed by exactly one `RELEASED` after baresip frees the call (`mem_deref` in the closed handler), after which the id is invalid.
- Every failure event carries a `bsk_error` with a status code and, when known, the SIP status and reason.
- A call ends as `FAILED` only when an outgoing call was not answered and this side did not end it; a cancelled outgoing call and a rejected incoming call end as `ENDED`.
- A `BSK_EVENT_CALL_STATE` that returns from `PAUSING`, `RESUMING` or `UPDATING` to the previous state carries an error when the other side rejected the change.
- After `bsk_account_unregister` the account reports `UNREGISTERING` and then `NONE`, and stays unregistered across network changes until `bsk_account_register` is called again.
- Events are never dropped; if the handler is slow the engine thread is slowed, which is observable in `BSK_EVENT_DIAGNOSTIC`.

## Open points for review

1. Audio I/O injection (external audio source/sink) is deliberately left out of revision 0.1; adding it means exposing `ausrc`/`auplay` style callbacks on media threads.
2. Whether `bsk_call_make` should accept per-call custom headers (baresip supports `call_set_custom_hdrs`). Proposed: yes, in revision 0.2.

## TLS

- The server certificate is always verified. `bsk_tls_config.insecure_skip_verify` is accepted only by a core built with the CMake option `BARESIPKIT_ALLOW_INSECURE_TLS` (off by default, and off in every released XCFramework and AAR); otherwise `bsk_engine_create` fails with `BSK_ERR_INVALID_ARGUMENT`. Pins together with `insecure_skip_verify` are always rejected. `extra_config` may not set `sip_verify_server`, `sip_cafile`, `sip_capath`, `sip_certificate` or `sip_verify_client`.
- `ca_pem` may hold several certificates. A chain that these do not anchor, or any chain when `ca_pem` is empty, is given to the system trust store: SecTrust with the SSL policy for the host on Apple platforms, OpenSSL's default verify paths elsewhere.
- `pinned_spki_sha256_base64` entries are base64 SHA-256 hashes (44 characters). A connection needs a verified chain and at least one certificate of it matching a pin.
- The same settings apply to SIP over TLS, to the WSS transport and to TURN over TLS.

## Input validation

Strings that end up in SIP messages or in baresip's configuration are rejected with `BSK_ERR_INVALID_ARGUMENT` when they contain control characters: URIs, user names, header names, reason phrases, module, device and interface names. The account's transport is added to a registrar or outbound proxy URI that has none, and a URI that names another transport is rejected. Values that do not fit the engine's buffers are rejected, not cut.
