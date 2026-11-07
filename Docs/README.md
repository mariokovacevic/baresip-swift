# BaresipKit documentation

The API reference and the Getting Started, Audio Session, Video, CallKit, PushKit and Push Contact Parameters articles are in the DocC catalog (`Sources/BaresipKit/BaresipKit.docc`); build it in Xcode with Product > Build Documentation.

| Document | Content |
|---|---|
| [Architecture.md](Architecture.md) | the layers, what lives where, threading and ownership |
| [Building.md](Building.md) | building the XCFramework, module sets, host builds, CI |
| [Integration.md](Integration.md) | engine lifecycle, accounts, push Contact parameters, calls, audio session, CallKit, PushKit, video, TLS, ICE and TURN, logging |
| [C-ABI.md](C-ABI.md) | ownership, threading, versioning and error conventions of `baresip_kit.h` |
| [CompatibilityMatrix.md](CompatibilityMatrix.md) | each requirement and how baresip covers it: as is, through a module, the facade or a patch |
| [Limitations.md](Limitations.md) | known limits and what automation does not cover |
| [DeviceTesting.md](DeviceTesting.md) | the manual test on a physical iPhone: camera, real audio, CallKit, PushKit and a real SIP server |
| [API_CHANGES.md](API_CHANGES.md) | public API renames and removals |
| [Research/](Research/README.md) | the feasibility report and the Contact parameter proof |

License obligations and the dependency inventory are in the repository root: `LICENSE`, `THIRD_PARTY_NOTICES.md`, `DEPENDENCIES.md`.
