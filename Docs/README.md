# BaresipKit documentation

BaresipKit has two SDKs over one C core: Swift for iOS and macOS, Kotlin for Android. Start with
the setup guide for your platform; the other documents go deeper.

## Setup guides

| Document | Content |
|---|---|
| [iOS.md](iOS.md) | iOS and macOS: modules, requirements, installation, quick start, setup recipes, app checklist, sample app |
| [Android.md](Android.md) | Android: modules, requirements, installation, quick start, setup recipes, app checklist, sample app, building, tests and releasing |

The Swift API reference and the Getting Started, Audio Session, Video, CallKit, PushKit,
SwiftUI, Network Changes and Push Contact Parameters articles are in the DocC catalog
(`Sources/BaresipKit/BaresipKit.docc`); build it in Xcode with Product > Build Documentation.
The Kotlin API reference is generated with Dokka (`./gradlew :dokkaGeneratePublicationHtml` in
`Android/`).

## Platform-specific

| Document | Content |
|---|---|
| [Integration.md](Integration.md) | Swift: engine lifecycle, accounts, push Contact parameters, calls, audio session, CallKit, PushKit, video, TLS, ICE and TURN, logging |
| [DeviceTesting.md](DeviceTesting.md) | Swift: the manual test on a physical iPhone: camera, real audio, CallKit, PushKit and a real SIP server |
| [Building.md](Building.md) | the XCFramework, module sets, the host build and CI; the Android build is in [Android.md](Android.md#building-from-source) |
| [Releasing.md](Releasing.md) | releasing the Swift package: version numbering, the changelog process and the XCFramework checksum; Android releases are in [Android.md](Android.md#releasing) |
| [Android/zvono/README.md](../Android/zvono/README.md) | Kotlin: Zvono for Android and its local deployment profile |

## Both platforms

| Document | Content |
|---|---|
| [Platforms.md](Platforms.md) | how the platforms share the core, the decisions behind the Android SDK, and parity type by type and test by test |
| [Architecture.md](Architecture.md) | the layers, what lives where, threading and ownership, for the Swift and the Kotlin stack |
| [C-ABI.md](C-ABI.md) | ownership, threading, versioning and error conventions of `baresip_kit.h`, the contract both SDKs bind |
| [Troubleshooting.md](Troubleshooting.md) | real failure modes (registration, audio, video, ICE, push, background) and how to read the log for each |
| [CompatibilityMatrix.md](CompatibilityMatrix.md) | each requirement and how baresip covers it: as is, through a module, the facade or a patch |
| [Interop.md](Interop.md) | the servers, door stations and TURN servers BaresipKit has been tried with, and how to report yours |
| [Limitations.md](Limitations.md) | known limits and what automation does not cover |
| [Patches/README.md](../Patches/README.md) | the patches applied to the pinned baresip and libre sources, and why |
| [Research/](Research/README.md) | the feasibility report and the Contact parameter proof |

License obligations and the dependency inventory are in the repository root: `LICENSE`,
`THIRD_PARTY_NOTICES.md`, `DEPENDENCIES.md`.
