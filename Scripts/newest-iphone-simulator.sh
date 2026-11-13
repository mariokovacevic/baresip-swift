#!/usr/bin/env bash
set -euo pipefail

xcrun simctl list devices available --json | python3 -c '
import json, re, sys
devices = json.load(sys.stdin)["devices"]
def version(key):
    match = re.search(r"iOS-(\d+)-(\d+)", key)
    return (int(match.group(1)), int(match.group(2))) if match else (0, 0)
for key in sorted((k for k in devices if "iOS" in k), key=version, reverse=True):
    phones = [d for d in devices[key] if d.get("isAvailable") and d["name"].startswith("iPhone")]
    if phones:
        print(phones[-1]["udid"])
        break
'
