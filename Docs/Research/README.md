# Research notes

The feasibility work done before the SDK was built: what was verified, and the proof that Contact parameters reach the wire unchanged. Kept for reference; the current documentation is one level up.

| Document | Content |
|---|---|
| `FeasibilityReport.md` | pins, toolchain, build proof (what was and was not verified), TLS backend, sizes, build pipeline, open items |
| `ContactParameterProof.md` | placement decision, proof programs, verified traces |
| `contact-parameter-trace.txt` | sanitized SIP trace, libre-level program |
| `contact-parameter-trace-baresip.txt` | sanitized SIP trace, baresip-level program with patch 0001 |
| `contact-parameter-trace-baresip-iossim.txt` | sanitized SIP trace, the same program built for the iOS simulator slice and run with `simctl spawn` |

Related files outside this directory: `Build/` (reproducible build), `Patches/` (upstreamable diffs), `Tools/ContactParameterProof/` (proof sources), `Core/include/baresip_kit.h` (the C ABI); the ABI conventions and the compatibility matrix are in `Docs/C-ABI.md` and `Docs/CompatibilityMatrix.md`.
