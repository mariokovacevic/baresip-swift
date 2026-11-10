#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source Scripts/source-files.sh

status=0

if ! c_sources | xargs clang-format --dry-run --Werror; then
  echo "C sources are not formatted; run Scripts/format.sh" >&2
  status=1
fi

if [[ "${SKIP_SWIFT:-0}" != 1 ]]; then
  if ! swift_sources | xargs swiftformat --lint --quiet --config .swiftformat; then
    echo "Swift sources are not formatted; run Scripts/format.sh" >&2
    status=1
  fi
  if ! swiftlint lint --strict --quiet --config .swiftlint.yml; then
    status=1
  fi
fi

exit "$status"
