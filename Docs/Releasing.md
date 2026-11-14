# Releasing

How a release is cut, as implemented by `.github/workflows/release.yml`. Nothing on this page
happens on its own: a maintainer starts every step.

## Versioning

BaresipKit follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html); what it covers is
in [STABILITY.md](STABILITY.md). A version is `MAJOR.MINOR.PATCH`, optionally with a pre-release
suffix such as `-rc.1`, and is published as a GitHub pre-release when it has one. Tags are
`v<version>`.

The version lives in one place, the `VERSION` file at the root. The core reads it at build time
(`bsk_version_string()` and the default `User-Agent`, `BaresipKit/<version>`), and the release
workflow refuses a version that differs from it.

## Before a release

In a pull request to the default branch:

1. Set `VERSION` to the version to release.
2. In `CHANGELOG.md`, rename `[Unreleased]` to `## [<version>] - <YYYY-MM-DD>`, add a link
   definition `[<version>]: …` at the end, and add a fresh, empty `[Unreleased]` section above.

Merge it and wait until CI is green for the merge commit.

## What the release workflow does

Run **Release** from the Actions tab on the default branch with the version. **Dry run** is on by
default: it performs every check, assembles every asset and uploads them as a workflow artifact
named `release-<version>`, and publishes nothing. Review that artifact, then run the workflow again
with dry run off.

1. **Checks** the version's shape, that the run is on the default branch, that `VERSION` matches,
   that `CHANGELOG.md` has a dated section and a link for the version, and that the latest CI run
   for the commit succeeded.
2. **Takes the XCFramework that CI built and tested** for that commit (the
   `BaresipKitCore.xcframework` artifact of the CI run, `MODULE_SET=default`), instead of
   building a new one, and checks its SwiftPM checksum.
3. **Assembles** the other assets:
   - `BaresipKitCore-licenses.zip`: BaresipKit's `LICENSE`, `LICENSES/` and
     `THIRD_PARTY_NOTICES.md`.
   - `BaresipKitCore.spdx.json`: an SPDX 2.3 SBOM from `Scripts/sbom.py`, listing the pinned
     components, the patches applied to them and the SHA-256 of the XCFramework.
   - `checksum.txt`: the SwiftPM checksum.
   - `SHA256SUMS`: the SHA-256 of every other asset.
   - Release notes: the version's section of `CHANGELOG.md` and the CI run that built the
     XCFramework.
4. Without dry run, from here on:
   - **Attests** the provenance of the assets (`actions/attest-build-provenance`). Check an
     asset with `gh attestation verify <file> --repo mariokovacevic/baresipkit`.
   - Creates a **draft** release `v<version>` with the assets.
   - Creates a release commit that sets `coreReleaseURL` and `coreReleaseChecksum` in
     `Package.swift`, **tags it** `v<version>` and pushes **only the tag**. The default branch
     keeps an empty URL, so it always builds the core from source; only the tag points SwiftPM at
     the published binary.
   - **Checks** the draft against the tag: every asset is there, `SHA256SUMS` matches, and the
     tagged `Package.swift` names this release's URL and the asset's checksum.
   - **Publishes** the release.

## Resuming a failed run

- **Failed before the tag was pushed:** run the workflow again with the same version. It replaces
  the draft release.
- **Failed after the tag was pushed:** run it again with the same version. It finds the tag, skips
  assembling, checks the draft against the tag and publishes it.
- **The release or an asset was deleted after the tag was pushed:** the tagged `Package.swift`
  can no longer be satisfied, because a new zip has a different checksum. Delete the tag
  (`git push --delete origin v<version>`) and run the workflow again, or release a new version.

## How SwiftPM resolves the core

`Package.swift` uses `Build/out/BaresipKitCore.xcframework` when `coreReleaseURL` is empty, which
is always the case on the default branch, or when the environment variable
`BARESIPKIT_LOCAL_CORE` is `1`. Otherwise, at a release tag, it downloads the release asset and
verifies its checksum. An app that depends on a version therefore always gets the binary that
was published for it, even if a local `Build/out` exists in a checkout of that tag.

## Not covered

- The XCFramework is a plain zip verified by its SwiftPM checksum and attestation. It is not
  code-signed.
- The Android libraries are released by `.github/workflows/release-android.yml`, described in
  its own section once its checks match this workflow.
