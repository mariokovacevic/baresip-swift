#!/usr/bin/env python3
import argparse
import datetime
import hashlib
import json
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
REPOSITORY = "https://github.com/mariokovacevic/baresipkit"
VERSION_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$")

COMPONENTS = [
    ("LIBRE", "libre", "BSD-3-Clause", "re"),
    ("BARESIP", "baresip", "BSD-3-Clause", "baresip"),
    ("OPENSSL", "OpenSSL", "Apache-2.0", None),
    ("OPUS", "Opus", "BSD-3-Clause", None),
    ("LIBVPX", "libvpx", "BSD-3-Clause", None),
]


def read_env(path):
    values = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value.strip('"')
    return values


def modules(module_set):
    text = (ROOT / "Build/module-sets.env").read_text()
    sets = dict(re.findall(r'^MODULES_(\w+)="([^"]*)"', text, re.M))
    if module_set not in sets:
        sys.exit(f"unknown module set {module_set}")
    expanded = sets[module_set]
    while "${MODULES_" in expanded:
        expanded = re.sub(r"\$\{MODULES_(\w+)\}", lambda m: sets[m.group(1)], expanded)
    return [name for name in expanded.split(";") if name]


def patches(project):
    return sorted(p.name for p in (ROOT / "Patches").glob(f"*-{project}-*.patch"))


def spdx_id(name):
    return "SPDXRef-" + re.sub(r"[^A-Za-z0-9.-]", "-", name)


def package(name, version, license_id, location, comment=None):
    entry = {
        "SPDXID": spdx_id(name),
        "name": name,
        "versionInfo": version,
        "downloadLocation": location,
        "filesAnalyzed": False,
        "licenseConcluded": license_id,
        "licenseDeclared": license_id,
        "copyrightText": "NOASSERTION",
        "supplier": "NOASSERTION",
    }
    if comment:
        entry["comment"] = comment
    return entry


def main():
    parser = argparse.ArgumentParser(description="Write an SPDX 2.3 SBOM of the BaresipKit core")
    parser.add_argument("--version", required=True)
    parser.add_argument("--module-set", default="default")
    parser.add_argument("--name", default="BaresipKitCore")
    parser.add_argument("--artifact", help="the file the SBOM describes, recorded with its SHA-256")
    args = parser.parse_args()

    if not VERSION_PATTERN.match(args.version):
        sys.exit(f"{args.version} is not a version like 1.2.3 or 1.2.3-rc.1")

    pins = read_env(ROOT / "Build/versions.env")
    selected = modules(args.module_set)
    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    created = datetime.datetime.fromtimestamp(int(epoch), datetime.timezone.utc) if epoch else datetime.datetime.now(datetime.timezone.utc)

    root = package(
        args.name,
        args.version,
        "BSD-3-Clause",
        f"git+{REPOSITORY}.git@v{args.version}",
        comment=f"Module set {args.module_set}: {', '.join(selected)}",
    )
    if args.artifact:
        data = pathlib.Path(args.artifact).read_bytes()
        root["packageFileName"] = pathlib.Path(args.artifact).name
        root["checksums"] = [{"algorithm": "SHA256", "checksumValue": hashlib.sha256(data).hexdigest()}]

    packages = [root]
    for key, name, license_id, project in COMPONENTS:
        if key == "LIBVPX" and "vp8" not in selected:
            continue
        applied = patches(project) if project else []
        comment = f"Patched with {', '.join(applied)} from Patches/" if applied else None
        packages.append(
            package(
                name,
                pins[f"{key}_TAG"],
                license_id,
                f"git+{pins[f'{key}_REPO']}@{pins[f'{key}_COMMIT']}",
                comment=comment,
            )
        )
    packages.append(
        package(
            "libg722",
            "a2688d2",
            "BSD-2-Clause",
            "git+https://github.com/sippy/libg722.git@a2688d2",
            comment="Vendored in Core/third_party/g722",
        )
    )

    document = {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": f"{args.name}-{args.version}",
        "documentNamespace": f"{REPOSITORY}/releases/v{args.version}/{args.name}-{args.module_set}.spdx.json",
        "creationInfo": {"created": created.strftime("%Y-%m-%dT%H:%M:%SZ"), "creators": ["Tool: BaresipKit Scripts/sbom.py"]},
        "documentDescribes": [root["SPDXID"]],
        "packages": packages,
        "relationships": [
            {"spdxElementId": root["SPDXID"], "relationshipType": "CONTAINS", "relatedSpdxElement": p["SPDXID"]}
            for p in packages[1:]
        ],
    }
    json.dump(document, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
