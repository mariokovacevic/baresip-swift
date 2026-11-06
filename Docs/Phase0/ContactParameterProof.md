# Contact parameter proof

Goal: show that push parameters configured on an account appear in the Contact header of every REGISTER exactly as given, survive the Digest authentication retry, survive timer-driven re-registration, can be updated without recreating anything, and are carried on the final unregister.

## Placement decision: Contact URI parameters

libre's registration client (`re/src/sipreg/reg.c:311-320`) formats the Contact as

```
Contact: <sip:USER@HOST:PORT;transport=X;<cparams>>;expires=N;<params>;reg-id=R
```

- `cparams` (inside the angle brackets, "Contact URI parameters") come from `sipreg_set_contact_params()`.
- `params` (after the brackets, "Contact header parameters") come from the `params` argument of `sipreg_alloc()`; baresip fills them with `+sip.instance`, `q` and the medianat tag from a fixed 256-byte buffer (`baresip/src/ua.c:170-213`).

BaresipKit places push parameters **inside the URI** (`cparams`):

1. It is the placement used by the common push-aware registrar conventions (`pn-provider`, `pn-prid`, `pn-param`, `app-id`, `pn-tok`, …), which expect the parameters in the Contact URI.
2. The value is stored with `str_dup()` without a size limit, while header parameters share the 256-byte buffer.
3. libre's `contact_handler()` matches the registrar's echoed Contact on user, host, port and transport only (`reg.c:148-190`), so extra URI parameters never break binding detection.
4. The string is emitted verbatim (`%s`, no escaping), so `:`, `&` and `;` separators reach the wire unchanged. The facade validates each value against the RFC 3261 `paramchar` set (`[-_.!~*'()%:&+$/\[\]A-Za-z0-9]`) and refuses anything else instead of encoding silently. `;` and `=` are rejected inside values because they are the separators.

## Programs

Both programs are in `Tools/ContactParameterProof/` and run against `fake_registrar.py`, a 100-line UDP registrar that challenges the first REGISTER with Digest MD5 (`qop=auth`), verifies the response, echoes the Contact with `expires` and writes a sanitized trace.

| Program | Layer | What it shows |
|---|---|---|
| `contact_proof.c` | libre only (`sipreg_*`) | The libre primitive works: `sipreg_set_contact_params()` + `sipreg_send()` on a live registration. |
| `contact_proof_baresip.c` | baresip UA API (`ua_alloc`, `ua_register`, `bevent`) with `Patches/0001` | The patched public API the Swift wrapper will call: `account_set_contact_params()` before the first REGISTER, `ua_set_contact_params()` to update tokens in place. |

Phases in both:

1. Initial REGISTER with token set A → 401 → REGISTER with Authorization, token set A → 200.
2. Token update to set B via the API → immediate REGISTER with set B (no unregister, no engine or UA recreation) → 200.
3. Timer-driven refresh (`regint=4` → refresh at 90 %) → REGISTER with set B → 200.
4. Unregister → REGISTER `expires=0` with set B → 200.

`verify_trace.py` parses the trace and checks the Contact of every REGISTER byte-for-byte against the expected parameter string and the sequence `A, A, B, B, B(expires=0)`.

## Result

Host run on 2026-11-06 (Linux x86_64, libre v4.9.0, baresip v4.9.0 + patch 0001):

```
REGISTER requests seen: 5
  [1] expires=4 token-set=A
  [2] expires=4 token-set=A
  [3] expires=4 token-set=B
  [4] expires=4 token-set=B
  [5] expires=0 token-set=B
RESULT: PASS
```

Both programs produce the same sequence. Traces:

- `contact-parameter-trace.txt` (libre program, loopback)
- `contact-parameter-trace-baresip.txt` (baresip program; the sandbox address `192.0.2.2` is a documentation range)

The tokens in the traces are synthetic 64-hex-digit strings. The combined Apple form `<remote>:remote&<voip>:voip` is used unchanged, as required.

## Reproduce

```bash
LIBRE_PREFIX=/path/to/libre/prefix Tools/ContactParameterProof/run.sh
```

```bash
LIBRE_PREFIX=... BARESIP_SRC=... BARESIP_BUILD=... Tools/ContactParameterProof/run_baresip.sh
```

## Notes for the facade

- `ua_set_contact_params()` sends a REGISTER immediately. If a REGISTER is already in flight, libre creates a second transaction; both responses are handled and the later one wins. The facade serializes token updates: while a REGISTER is outstanding it stores the new value and applies it on the next `REGISTER_OK`/`REGISTER_FAIL`. A libre helper exposing the pending state would remove that bookkeeping (optional upstream change).
- A re-registration triggered by `ua_register()` instead would recreate the `sipreg` and libre's destructor would first send an unregister for the old binding (`sipreg/reg.c:84`). That is why the patch updates the live client instead.
- Baresip excludes loopback addresses from its network list (`src/net.c:628`), so the baresip-level program binds to the first non-loopback interface.
- Consumers of libre must compile with the same `HAVE_UNIXSOCK` value as the library, because it changes the size of `struct sa` (`re_sa.h:39`). The first proof build crashed on exactly this. The XCFramework build keeps libre's default (Unix sockets on) and the facade is compiled from the same CMake tree, so the Swift package never sees libre structs.
