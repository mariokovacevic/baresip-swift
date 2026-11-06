# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub: open the repository's **Security** tab
and choose **Report a vulnerability**. Do not open a public issue.

Include what you found, how to reproduce it, and the affected version or commit. Remove
credentials, push tokens and personal data from logs and SIP traces before attaching them.

We aim to acknowledge a report within five working days and to agree on a fix and a disclosure
date with you. Fixes are released as a patch version and described in `CHANGELOG.md`.

## Supported versions

Until 1.0, only the latest release receives security fixes.

## Scope

In scope: the BaresipKit facade (`Core/`), the Swift modules, the patches in `Patches/` and the
build scripts. Vulnerabilities in baresip, libre, OpenSSL or Opus themselves should also be
reported to their projects; we update the pinned versions when they publish fixes.
