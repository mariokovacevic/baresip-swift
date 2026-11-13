#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
SHOTS="${SHOTS:-$ROOT/Build/out/screenshots}"
PEER="$ROOT/Build/out/host/core-tests/tests/bsk_test_call"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<USAGE
Usage: Tools/SampleScreenshots/run.sh

Runs the sample app's screenshot test on an iOS simulator: demo doors, activity and messages,
a ring from a door and a call to it. Builds what is missing, starts a TLS registrar, the
ringing door and an answering peer on this Mac, and saves the screenshots.

Environment:
  PAUSE     seconds to stay on each screen, to watch it in Simulator (default 0)
  SIM_UDID  simulator to use (default: the newest iPhone)
  HOSTIP    this Mac's LAN address (default: en0, then en1)
  SHOTS     folder for the screenshots (default Build/out/screenshots)
USAGE
  exit 0
fi

if [[ "$(uname)" != Darwin ]]; then
  echo "This needs macOS with Xcode." >&2
  exit 1
fi
if ! command -v xcodegen >/dev/null; then
  echo "Install XcodeGen first: brew install xcodegen" >&2
  exit 1
fi
HOSTIP="${HOSTIP:-$(ipconfig getifaddr en0 || ipconfig getifaddr en1 || true)}"
if [[ -z "$HOSTIP" ]]; then
  echo "No LAN address found; set HOSTIP to this Mac's address." >&2
  exit 1
fi

if [[ ! -d Build/out/BaresipKitCore.xcframework ]]; then
  echo "Building the XCFramework (the first time takes a while)"
  MODULE_SET=default Build/build-xcframework.sh
fi
if [[ ! -x "$PEER" ]]; then
  echo "Building the test peer"
  if [[ ! -d Build/out/host/prefix ]]; then
    PLATFORM=host MODULE_SET=full Build/build-xcframework.sh
  fi
  BUILD_ONLY=1 PREFIX=Build/out/host/prefix Tests/Core/run_tests.sh
fi

if [[ -z "${SIM_UDID:-}" ]]; then
  SIM_UDID=$(Scripts/newest-iphone-simulator.sh)
fi
if [[ -z "$SIM_UDID" ]]; then
  echo "No iPhone simulator found; add one in Xcode, Settings, Components." >&2
  exit 1
fi
xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
if [[ -z "${CI:-}" ]]; then
  open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" 2>/dev/null \
    || open -a DeviceHub 2>/dev/null \
    || echo "Open Device Hub or Simulator to watch $SIM_UDID" >&2
fi

# Empty the folder rather than remove it: Finder, opened on it by the last run, writes .DS_Store into it.
mkdir -p "$SHOTS"
find "$SHOTS" -mindepth 1 -delete 2>/dev/null || true
cat > "$SHOTS/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = baresipkit-screenshots
[ext]
subjectAltName = IP:$HOSTIP
EOF
openssl req -x509 -newkey rsa:2048 -nodes -days 2 -keyout "$SHOTS/key.pem" -out "$SHOTS/cert.pem" \
  -config "$SHOTS/cert.cnf" >/dev/null 2>&1

PIDS=()
cleanup() {
  for pid in ${PIDS[@]+"${PIDS[@]}"}; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

REGISTRAR_HOST="$HOSTIP" REGISTRAR_PORT=5082 REGISTRAR_PEER="$HOSTIP:5072,$HOSTIP:5070" REGISTRAR_IDLE_TIMEOUT=600 \
  python3 Tools/ContactParameterProof/tls_registrar.py "$SHOTS/cert.pem" "$SHOTS/key.pem" \
  "$SHOTS/registrar-trace.txt" > "$SHOTS/registrar.out" 2>&1 &
PIDS+=($!)
python3 Tools/SampleScreenshots/ring.py "$HOSTIP" 5082 5072 "$SHOTS/registrar-trace.txt" "$SHOTS/ring.trigger" \
  "$SHOTS/message.trigger" > "$SHOTS/ring.out" 2>&1 &
PIDS+=($!)
BSK_PEER_TIMEOUT=600 "$PEER" peer "$HOSTIP" > "$SHOTS/peer.out" 2> "$SHOTS/peer.err" &
PIDS+=($!)
for _ in $(seq 1 50); do
  grep -q READY "$SHOTS/peer.out" 2>/dev/null && break
  sleep 0.2
done

cd Examples/SampleApp
xcodegen generate >/dev/null
echo "Running the screenshot test on $SIM_UDID with the registrar at $HOSTIP:5082"
TEST_RUNNER_BSK_UITEST_HOST="$HOSTIP" TEST_RUNNER_BSK_UITEST_PORT=5082 \
TEST_RUNNER_BSK_UITEST_CA_PEM="$(cat "$SHOTS/cert.pem")" TEST_RUNNER_BSK_SCREENSHOTS="$SHOTS" \
TEST_RUNNER_BSK_SCREENSHOT_PAUSE="${PAUSE:-0}" \
  xcodebuild test -project BaresipKitSample.xcodeproj -scheme BaresipKitSample \
  -destination "id=${SIM_UDID}" -only-testing:BaresipKitSampleUITests/ScreenshotTests \
  -resultBundlePath "$SHOTS/screenshots.xcresult" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= 2>&1 \
  | tee "$SHOTS/test.log" | grep -E "Test Case|error:|XCTAssert|TEST (SUCCEEDED|FAILED)" || true

if ! ls "$SHOTS"/*.png >/dev/null 2>&1; then
  xcrun xcresulttool export attachments --path "$SHOTS/screenshots.xcresult" --output-path "$SHOTS" || true
fi
echo "--- ring"
cat "$SHOTS/ring.out" || true
echo "--- screenshots in $SHOTS"
ls "$SHOTS"/*.png 2>/dev/null || echo "none"
if [[ -z "${CI:-}" ]] && ls "$SHOTS"/*.png >/dev/null 2>&1; then
  open "$SHOTS"
fi
