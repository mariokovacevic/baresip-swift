# Stability and versioning

BaresipKit follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html) from 1.0.0 on.
This page says what that promise covers, what it does not, and how changes are made.

## What SemVer covers

- **The public Swift API** of the products in `Package.swift`: `BaresipKit`, `BaresipKitAudio`,
  `BaresipKitVideo`, `BaresipKitCallKit`, `BaresipKitLiveCommunication`, `BaresipKitPushKit` and
  `BaresipKitSwiftUI`. Every `public` and `open` declaration, except those listed under
  [What SemVer does not cover](#what-semver-does-not-cover).
- **The public Kotlin API** of the libraries published to Maven Central: `baresipkit`,
  `baresipkit-audio`, `baresipkit-video`, `baresipkit-telecom`, `baresipkit-push` and
  `baresipkit-compose`. Every public declaration, except those listed below. Source and binary
  compatibility are both covered on Android, because apps resolve the libraries as binaries.
- **Behaviour that the API documentation states**, such as the order of events, the defaults of
  configuration types and the meaning of errors.
- **The minimum OS versions**: iOS 16, macOS 13 on Apple silicon and Android 9 (API 28). They are
  raised only in a major release.

A **patch** release (1.0.x) fixes bugs without changing the public API. A **minor** release
(1.x.0) adds API and features and may deprecate API. A **major** release removes deprecated API,
makes other incompatible changes, or raises a minimum OS version.

## What SemVer does not cover

- **The C ABI** in `Core/include/baresip_kit.h` and `Core/include/baresip_kit_android.h`. Both SDKs
  bundle the core in the same version, so the C ABI changes together with them, and its version
  (`bsk_abi_version()`) only tells a binding which header it was built against. A program that
  binds the C ABI directly must be rebuilt with every BaresipKit release. The C ABI may become
  public in a later minor release; this page will say so.
- **Internal modules and targets**: `BaresipKitBridge`, `BaresipKitSystemCall` and the
  `internal` packages and declarations of the Kotlin libraries.
- **API that is marked as not stable**: Swift declarations behind `@_spi`, and Kotlin
  declarations that need an opt-in annotation. Their documentation says so.
- **Log messages, SIP traces and the file log's format.** They help with debugging and change in
  any release. Do not parse them.
- **The baresip module names and the `extraConfiguration` / `extraConfig` text** passed to the
  engine. They depend on the bundled baresip version, which a minor release may update.
- **The sample apps** (`Examples/SampleApp`, `Android/zvono`) and everything in `Tools/`.
- **Exact timing**, for example how long a timeout takes or how often statistics arrive, unless
  the documentation states it.
- **Creating output types yourself.** Types that the SDK returns or emits, such as
  `BaresipCallInfo`, `BaresipCallStatistics`, `BaresipMessage` and the event payloads, gain
  properties in minor releases. Their initializers, and in Kotlin their constructors, `copy` and
  `componentN` functions, are not covered: create them only in tests, and expect to update those
  tests. Reading their properties is covered.
- **Implementing protocols and interfaces that the SDK implements**, such as
  `BaresipCallController`. Requirements may be added to them in a minor release.

## Enumerations and events that grow

New cases can be added to enumerations and new subtypes to sealed hierarchies in a **minor**
release. This applies to every public enumeration and sealed type, among them `BaresipEvent`,
`BaresipCallState`, `BaresipError.Code`, `BaresipMediaEvent`, `BaresipCallEndReason`,
`BaresipEngineState`, `BaresipRegistrationState`, `BaresipICEState` / `BaresipIceState`,
`BaresipCandidateType` and `BaresipAudioRoute`, and to the error enumerations of the adapters.

Write code that keeps compiling when a case is added:

- **Swift:** end a `switch` over a BaresipKit enumeration with `default:`, or handle only the cases
  you need with `if case`. The package is built from source without library evolution, so
  `@unknown default` does not apply.
- **Kotlin:** give every `when` over a BaresipKit enum or sealed type an `else ->` branch.

A minor release never removes a case, and never changes the meaning of an existing one. The C
ABI follows the same rule: a binding must ignore event types, enum values and media events it does
not know.

## Deprecation

- An API is deprecated in a minor release, with `@available(*, deprecated, message:)` in Swift and
  `@Deprecated(message, ReplaceWith(...))` in Kotlin, and the replacement is named in the message
  and in `CHANGELOG.md`.
- A deprecated API stays for at least one minor release and is removed only in the next major
  release.
- A deprecated API keeps working as documented until it is removed, unless it is a security
  problem; then the release notes say why it changed.

## Minimum OS versions

- A minimum OS version is raised only in a major release, and only after it has been announced in
  the release notes of a minor release before.
- New API that needs a newer OS than the minimum is marked with `@available` in Swift or
  `@RequiresApi` in Kotlin; for example the LiveCommunicationKit adapter needs iOS 17.4.

## Security fixes

A security fix can change behaviour in a patch release when the old behaviour was the
vulnerability; the release notes and `CHANGELOG.md` say so under "Security". See
[SECURITY.md](../SECURITY.md) for reporting.

## Supported versions

Only the latest minor release of the latest major version gets fixes. A security fix may also be
released for the previous minor release when an upgrade is not reasonable; the release notes say
so.
