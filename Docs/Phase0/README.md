# Phase 0 deliverables

| Document | Content |
|---|---|
| `FeasibilityReport.md` | pins, toolchain, build proof (what was and was not verified), TLS backend, sizes, build pipeline, open items |
| `CompatibilityMatrix.md` | every requirement classified as as-is / module / facade / patch / not feasible with source references |
| `ContactParameterProof.md` | placement decision, proof programs, verified traces |
| `C-ABI.md` | ownership, threading and error conventions for `baresip_kit.h` |
| `contact-parameter-trace.txt` | sanitized SIP trace, libre-level program |
| `contact-parameter-trace-baresip.txt` | sanitized SIP trace, baresip-level program with patch 0001 |

Related files outside this directory: `Build/` (reproducible build), `Patches/` (upstreamable diffs), `Tools/ContactParameterProof/` (proof sources), `Sources/BaresipKitCore/include/baresip_kit.h` (proposed ABI).
