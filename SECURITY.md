# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub: open the repository's **Security** tab
and choose **Report a vulnerability**. Do not describe the vulnerability in a public issue.

If that form is not available to you, open a public issue titled "Security contact request",
with no details of the vulnerability, and a maintainer will give you a private channel.

Include what you found, how to reproduce it, and the affected version or commit. Remove
credentials, push tokens and personal data from logs and SIP traces before attaching them.

We aim to acknowledge a report within five working days and to agree on a fix and a disclosure
date with you. Fixes are released as a patch version and described in `CHANGELOG.md`.

## Supported versions

Security fixes go to the latest minor release of the latest major version, as a patch release.
[STABILITY.md](Docs/STABILITY.md#supported-versions) says when an older minor release also gets
one. Fixes that change behaviour are listed under "Security" in `CHANGELOG.md`.

## Scope

In scope: the BaresipKit facade (`Core/`), the Swift modules, the Android libraries, the patches
in `Patches/` and the build and release scripts. Vulnerabilities in baresip, libre, OpenSSL or Opus themselves should also be
reported to their projects; we update the pinned versions when they publish fixes.
