#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
deps="$root/Build/.deps"
pairs=(
  "re/LICENSE:libre-LICENSE"
  "baresip/LICENSE:baresip-LICENSE"
  "openssl/LICENSE.txt:OpenSSL-LICENSE.txt"
  "opus/COPYING:Opus-COPYING"
  "libvpx/LICENSE:libvpx-LICENSE"
  "libvpx/PATENTS:libvpx-PATENTS"
)

status=0
for pair in "${pairs[@]}"; do
  upstream="$deps/${pair%%:*}"
  copy="$root/LICENSES/${pair##*:}"
  if [[ ! -f "$upstream" ]]; then
    echo "error: $upstream is missing; fetch the pinned sources with Build/build-xcframework.sh" >&2
    status=1
  elif ! cmp -s "$upstream" "$copy"; then
    echo "error: LICENSES/${pair##*:} differs from ${pair%%:*} at the pinned commit; copy it again" >&2
    status=1
  fi
done
if ! cmp -s "$root/Core/third_party/g722/LICENSE" "$root/LICENSES/libg722-LICENSE"; then
  echo "error: LICENSES/libg722-LICENSE differs from Core/third_party/g722/LICENSE" >&2
  status=1
fi
[[ "$status" != 0 ]] || echo "LICENSES matches the pinned sources"
exit "$status"
