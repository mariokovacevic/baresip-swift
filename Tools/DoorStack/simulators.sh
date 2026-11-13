#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE="$ROOT/Tools/DoorStack/state"
APP_DIR="$ROOT/Examples/SampleApp"
DERIVED="$ROOT/Build/out/simulators"
BUNDLE=com.example.BaresipKitSample
COUNT="${COUNT:-2}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<USAGE
Usage: Tools/DoorStack/simulators.sh

Starts the sample app on iPhone simulators signed in to the door stack, for trying calls live:
the first as resident 100, the second as 101, over TLS with the stack's CA, each with door1 as
its Front door. Start the stack first: Tools/DoorStack/doorstack.sh start

Then call Neighbour 101 from 100 in Keypad, Contacts, look at the Front door (video from the door station, the
code 1234 opens it), or ring a simulator from the door: Tools/DoorStack/doorstack.sh ring 100

Environment:
  COUNT     number of simulators, 1 or 2 (default 2)
  HOSTIP    this Mac's LAN address (default: en0, then en1)
USAGE
  exit 0
fi

if [[ "$(uname)" != Darwin ]] || ! command -v xcodegen >/dev/null; then
  echo "This needs macOS with Xcode and XcodeGen (brew install xcodegen)." >&2
  exit 1
fi
HOSTIP="${HOSTIP:-$(ipconfig getifaddr en0 || ipconfig getifaddr en1 || true)}"
PASSWORD="$(sed -n 's/^RESIDENT_PASSWORD=//p' "$STATE/secrets.env" 2>/dev/null || true)"
CA="$STATE/asterisk/keys/asterisk.pem"
if [[ -z "$PASSWORD" || ! -f "$CA" ]] || ! curl -fsS http://127.0.0.1:8089/status >/dev/null 2>&1; then
  echo "The door stack is not running; start it with: Tools/DoorStack/doorstack.sh start" >&2
  exit 1
fi
if [[ ! -d "$ROOT/Build/out/BaresipKitCore.xcframework" ]]; then
  echo "Building the XCFramework (the first time takes a while)"
  (cd "$ROOT" && MODULE_SET=default Build/build-xcframework.sh)
fi

echo "Building the sample app for the simulator"
(cd "$APP_DIR" && xcodegen generate >/dev/null)
xcodebuild build -project "$APP_DIR/BaresipKitSample.xcodeproj" -scheme BaresipKitSample \
  -configuration Debug -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/BaresipKitSample.app"

# The newest iOS runtime's iPhones, as many as needed.
read -r -a SIMS <<<"$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys
d = json.load(sys.stdin)["devices"]
def ver(k):
    m = re.search(r"iOS-(\d+)-(\d+)", k)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)
for key in sorted((k for k in d if "iOS" in k), key=ver, reverse=True):
    phones = [x["udid"] for x in d[key] if x.get("isAvailable") and x["name"].startswith("iPhone")]
    if phones:
        print(" ".join(phones[:'"$COUNT"']))
        break
')"
if (( ${#SIMS[@]} < COUNT )); then
  echo "Found ${#SIMS[@]} iPhone simulators, need $COUNT; add them in Xcode, Window, Devices and Simulators." >&2
  exit 1
fi

USERS=(100 101)
for i in $(seq 0 $((COUNT - 1))); do
  sim="${SIMS[$i]}"
  xcrun simctl boot "$sim" 2>/dev/null || true
  xcrun simctl install "$sim" "$APP"
  SIMCTL_CHILD_BSK_UITEST=1 SIMCTL_CHILD_BSK_UITEST_CA_PEM="$(cat "$CA")" SIMCTL_CHILD_BSK_LIVE_AUDIO=1 \
  SIMCTL_CHILD_BSK_DEMO=1 SIMCTL_CHILD_BSK_DEMO_HOST="$HOSTIP" SIMCTL_CHILD_BSK_DEMO_PORT=5061 \
  SIMCTL_CHILD_BSK_DEMO_USER="${USERS[$i]}" SIMCTL_CHILD_BSK_DEMO_PASSWORD="$PASSWORD" \
  SIMCTL_CHILD_BSK_DEMO_DOOR="sip:door1@$HOSTIP" SIMCTL_CHILD_BSK_DEMO_DOOR_CODE="${DOOR_CODE:-1234}" \
  SIMCTL_CHILD_BSK_DEMO_CONTACT="${USERS[$((1 - i))]}" SIMCTL_CHILD_BSK_DEMO_CONTACT_NAME="Neighbour ${USERS[$((1 - i))]}" \
    xcrun simctl launch --terminate-running-process "$sim" "$BUNDLE" >/dev/null
  echo "Resident ${USERS[$i]} on $(xcrun simctl list devices | grep "$sim" | sed 's/ (.*//;s/^ *//')"
done
open -a Simulator 2>/dev/null || open -a DeviceHub 2>/dev/null || true

cat <<NEXT

The app registers over TLS with $HOSTIP:5061. To try:
  - call or write to the other phone: Keypad, Contacts, Neighbour 101
  - look at the Front door: Doors, the picture; the code ${DOOR_CODE:-1234} opens it
  - ring a simulator from the door: Tools/DoorStack/doorstack.sh ring 100
NEXT
