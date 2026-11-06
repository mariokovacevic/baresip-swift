# Patches

Every file in this directory is a unified diff against the pinned upstream
commit listed in `Build/versions.env`. The build script applies them in
lexical order with `git apply --3way` before configuring CMake. Each patch is
kept as small as possible so that it can be proposed upstream unchanged.

| Patch | Target | Rationale | Upstream status |
|---|---|---|---|
| `0001-baresip-account-contact-uri-params.patch` | baresip v4.9.0 | libre already supports Contact URI parameters on REGISTER through `sipreg_set_contact_params()`, but baresip never calls it and offers no public setter. The patch adds `account_set_contact_params()` / `account_contact_params()` and wires the value into `reg_register()` so every REGISTER (initial, auth retry, refresh, re-register after a token update, unregister) carries the parameters inside the Contact URI. | to be proposed |
| `0002-baresip-avcapture-cmake-ios.patch` | baresip v4.9.0 | `modules/avcapture/CMakeLists.txt` only enables the module when `CMAKE_SYSTEM_NAME` is `Darwin`. An iOS cross-build sets `CMAKE_SYSTEM_NAME=iOS`, so the AVFoundation capture module was silently dropped from iOS builds. The patch accepts `iOS` as well. Note that the module still contains macOS-only API (`AVCaptureScreenInput`) and manual reference counting; see the feasibility report for why BaresipKit ships its own capture source anyway. | to be proposed |

## Verifying a patch

```bash
git -C <baresip checkout> apply --check Patches/0001-baresip-account-contact-uri-params.patch
```
