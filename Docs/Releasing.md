# Releasing

How a release is cut, strictly as implemented by `.github/workflows/release.yml` and
`Build/build-xcframework.sh`. There is no release yet; this is the process the first and every
later one will follow.

## Versioning

The project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html): `MAJOR.MINOR.PATCH`,
optionally with a pre-release suffix such as `-beta.1`. The release workflow enforces the shape
with a regular expression (`^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$`); a version such as `0.1.0`
or `0.1.0-beta.1` is accepted, `v0.1.0` or `0.1` is not. While the project is in beta (0.x), a
breaking API change bumps the minor version, not the major one, as SemVer allows before 1.0.0. A
version tagged with a pre-release suffix is published as a GitHub pre-release.

## Changelog process

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Every pull
request adds an entry under the `[Unreleased]` section (the pull request checklist in
`CONTRIBUTING.md` requires it). Cutting a release means renaming `[Unreleased]` to the new
version and date, removing the "Beta, not released yet" note once the project leaves beta, and
adding a fresh empty `[Unreleased]` section above it. The release workflow does not touch
`CHANGELOG.md`; update it in its own commit (or as part of the pull request that triggers the
release) before running the workflow, since the workflow only builds, tags and publishes.

## What the release workflow does

Run the **Release** workflow from the Actions tab (`workflow_dispatch`) on the default branch,
giving a version such as `0.1.0`. It:

1. Checks the version's shape, that the run is on the default branch, and that the latest CI run
   for the current commit succeeded (`gh run list --workflow ci.yml`); it refuses otherwise.
2. Builds the XCFramework with `MODULE_SET=default` (`Build/build-xcframework.sh`).
3. Collects the license texts of BaresipKit, libre, baresip, OpenSSL, Opus and libg722, plus
   `THIRD_PARTY_NOTICES.md`, into `BaresipKitCore-licenses.zip`.
4. Creates a **draft** GitHub release at tag `v<version>` with three assets:
   `BaresipKitCore.xcframework.zip`, `BaresipKitCore-licenses.zip` and `checksum.txt` (the SPM
   binary target checksum, from `swift package compute-checksum`, computed by the build script
   over the exact zip that is uploaded).
5. Writes `coreReleaseURL` (the download URL of the zip, on this GitHub repository) and
   `coreReleaseChecksum` into `Package.swift`, commits that change, tags the commit `v<version>`,
   and pushes the branch and the tag **in one atomic push** (`git push --atomic`). A tag therefore
   never exists without its assets already uploaded.
6. Publishes the draft release (`gh release edit --draft=false`).

Nothing here is invented: every step is a direct read of `release.yml`. The checksum changes on
every rebuild because the zip carries timestamps, so step 4 always runs before step 5 computes
the checksum from the actual uploaded file.

## Resuming a failed run

- **Failed before the push** (steps 1–5): run the workflow again with the same version. No tag
  exists yet, so it builds again and replaces the draft release.
- **Failed after the push** (step 6, or a runner problem right after): run the workflow again
  with the same version. The workflow detects the existing tag and, instead of building again,
  checks that the release has all three assets and that the XCFramework asset's checksum matches
  the one recorded in the tagged `Package.swift`, then publishes it.
- **The release or an asset was deleted after the tag was pushed**: the tagged `Package.swift` can
  no longer be satisfied by anything the workflow can produce (rebuilding gives a different
  checksum, since the archive carries timestamps). Delete the tag
  (`git push --delete origin v<version>`) and run the workflow again, or release a new version
  instead.

## After a release exists

Once a release has been published, `Package.swift` resolves `BaresipKitCore` locally when
`Build/out/BaresipKitCore.xcframework` exists, and otherwise downloads the asset of the latest
tagged `coreReleaseURL`/`coreReleaseChecksum`. Apps that depend on a released version add the
package by URL and a version requirement instead of a local path; see
[Building.md](Building.md#using-the-package). Each new release updates `coreReleaseURL` and
`coreReleaseChecksum` again through the same workflow, so an app that pins a version keeps
resolving the XCFramework that was published for it.

## Gaps not covered by the workflow

These are not implemented, so they are not described as if they were:

- No automated check that `CHANGELOG.md` has a dated entry for the version being released.
- No automatic update of `README.md`'s beta badge or installation instructions when the first
  release is cut; that remains a manual documentation step (this file and the root `README.md`).
- No signing or notarization step for the XCFramework; it is distributed as a plain zip with a
  SPM checksum.
