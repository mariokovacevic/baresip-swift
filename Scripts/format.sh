#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source Scripts/source-files.sh

c_sources | xargs clang-format -i
if command -v swiftformat >/dev/null; then
  swift_sources | xargs swiftformat --quiet --config .swiftformat
else
  echo "swiftformat not found; install it with: brew install swiftformat" >&2
  exit 1
fi
