# Public API changes

Changes to the public Swift API. Renamed symbols keep a deprecated alias for at least one minor
release, so existing code still compiles, with a fix-it to the new name.

## Renamed

| Before | After | Module | Compatibility |
|---|---|---|---|
| `ContactParameter` | `BaresipContactParameter` | BaresipKit | deprecated `typealias ContactParameter` |
| `TURNServer` | `BaresipTURNServer` | BaresipKit | deprecated `typealias TURNServer` |
| `BaresipEngine.resume()` | `BaresipEngine.resumeFromBackground()` | BaresipKit | deprecated `resume()` forwards to the new method; `resume(callID:)` for calls is unchanged |

## Added

| Symbol | Module | Why |
|---|---|---|
| `BaresipMediaEvent.unknown` | BaresipKit | a core newer than the Swift layer can report media events the Swift layer does not know; they were reported as `.audioStarted` before |
| `BaresipAudioConfiguration.defaultCodecs` | BaresipKit | names the default codec list used by `init` |

## Removed

| Symbol | Module | Why |
|---|---|---|
| `BaresipVideoSupport` (`status` string) | BaresipKitVideo | a placeholder description string with no behavior |

## Behavior changes

- `BaresipEngine.reject(callID:statusCode:reason:)` clamps the status code to 0–699 before passing it to the core, instead of trapping for values outside `UInt16`. The core still rejects codes outside 300–699 with `invalidArgument`.
- `BaresipCallKitAdapter` no longer keeps itself alive through its event loop; it is released when the app drops its last reference.

## Proposed, not applied

These would make the API more consistent but break source compatibility without an easy alias. They are kept for a future major version.

- Value-first argument order for every setter: `setVideoMaxBitrate(callID:bitsPerSecond:)` would become `setVideoMaxBitrate(_:callID:)`, matching `setMicrophoneMuted(_:callID:)`.
- Transfer naming: `transfer(callID:to:)` (blind) and `transferAttended(callID:to:)` could become `blindTransfer(callID:to:)` and `attendedTransfer(callID:replacing:)`.
- `BaresipError` as a nested `BaresipError.Code` instead of the top-level `BaresipStatus`.
