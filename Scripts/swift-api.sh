#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: Scripts/swift-api.sh dump|check" >&2
  exit 2
}

mode=${1:-}
[[ "$mode" == dump || "$mode" == check ]] || usage

root=$(cd "$(dirname "$0")/.." && pwd)
baselines="$root/API/Swift"
out="$root/Build/out/swift-api"
dumps="$out/dumps"
modules=(BaresipKit BaresipKitAudio BaresipKitVideo BaresipKitCallKit BaresipKitLiveCommunication BaresipKitPushKit
  BaresipKitSwiftUI)

[[ -d "$root/Build/out/BaresipKitCore.xcframework" ]] || {
  echo "Build/out/BaresipKitCore.xcframework is missing; run Build/build-xcframework.sh first" >&2
  exit 1
}

mkdir -p "$out"
rm -rf "$dumps"
mkdir -p "$dumps"

echo "Building the package for the iOS Simulator"
build=(-scheme BaresipKit-Package -destination 'generic/platform=iOS Simulator')
if ! (cd "$root" && xcodebuild build "${build[@]}") >"$out/build.log" 2>&1; then
  grep -E "error:" "$out/build.log" | sort -u | head -40 || true
  tail -20 "$out/build.log"
  exit 1
fi

derived="${DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData}"
module=$(find "$derived" -maxdepth 6 -type d -name BaresipKit.swiftmodule -path '*/Debug-iphonesimulator/*' \
  -print 2>/dev/null | head -1)
products=${module%/BaresipKit.swiftmodule}
[[ -n "$module" && -d "$products" ]] || {
  echo "error: no BaresipKit.swiftmodule for the iOS Simulator under $derived" >&2
  find "$derived" -maxdepth 4 -type d -name 'Debug-iphonesimulator' 2>/dev/null | head >&2
  exit 1
}
echo "Products: $products"
headers=$(find "$root/Build/out/BaresipKitCore.xcframework" -type d -path '*simulator/Headers' | head -1)
[[ -n "$headers" ]] || {
  echo "no simulator slice in the XCFramework" >&2
  exit 1
}
flags=(
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
  -target arm64-apple-ios16.0-simulator
  -I "$products"
  -F "$products"
  -Xcc "-I$root/Sources/BaresipKitBridge/include"
  -Xcc "-I$headers"
)

declarations() {
  jq -r '[.. | objects | select(.usr? and .kind != "TypeNominal") | .usr] | unique | .[]' "$1"
}

status=0
for module in "${modules[@]}"; do
  dump="$dumps/$module.json"
  if ! xcrun swift-api-digester -dump-sdk -module "$module" -o "$dump" -avoid-location \
    "${flags[@]}" 2>"$out/$module.dump.log"; then
    echo "error: could not dump the API of $module" >&2
    cat "$out/$module.dump.log" >&2
    status=1
    continue
  fi
  [[ "$mode" == check ]] || continue

  baseline="$baselines/$module.json"
  if [[ ! -f "$baseline" ]]; then
    echo "error: $module has no baseline in API/Swift; run Scripts/swift-api.sh dump and commit it" >&2
    status=1
    continue
  fi

  report="$out/$module.breakage.txt"
  xcrun swift-api-digester -diagnose-sdk -module "$module" -baseline-path "$baseline" -o "$report" \
    "${flags[@]}" 2>"$out/$module.diagnose.log" || {
    echo "error: could not compare the API of $module" >&2
    cat "$out/$module.diagnose.log" >&2
    status=1
    continue
  }
  if grep -vE '^[[:space:]]*$|^/\*' "$report" >"$report.entries"; then
    echo "error: breaking changes in $module:" >&2
    cat "$report.entries" >&2
    status=1
  fi

  added=$(comm -13 <(declarations "$baseline") <(declarations "$dump"))
  removed=$(comm -23 <(declarations "$baseline") <(declarations "$dump"))
  if [[ -n "$added$removed" ]]; then
    echo "error: the public API of $module differs from API/Swift/$module.json" >&2
    [[ -z "$added" ]] || sed 's/^/  added: /' <<<"$added" >&2
    [[ -z "$removed" ]] || sed 's/^/  removed: /' <<<"$removed" >&2
    echo "  Run Scripts/swift-api.sh dump on macOS and commit API/Swift with the change." >&2
    status=1
  fi
done

if [[ "$mode" == dump && "$status" == 0 ]]; then
  mkdir -p "$baselines"
  cp "$dumps"/*.json "$baselines"/
  echo "Wrote the baselines to API/Swift"
fi
exit "$status"
