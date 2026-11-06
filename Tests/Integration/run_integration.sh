#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PREFIX="${PREFIX:?set PREFIX to a host build prefix}"
BUILD="${BUILD_DIR:-$ROOT/Build/out/host/core-tests}"
HOSTIP="${HOSTIP:?set HOSTIP to the address Asterisk is reachable on}"

mkdir -p "$HERE/asterisk/keys"
chmod 755 "$HERE/asterisk/keys"
if [[ ! -f "$HERE/asterisk/keys/asterisk.pem" ]]; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$HERE/asterisk/keys/asterisk.key" -out "$HERE/asterisk/keys/asterisk.pem" -days 30 \
    -subj "/CN=asterisk" -addext "subjectAltName=IP:$HOSTIP" >/dev/null 2>&1
fi
chmod 644 "$HERE/asterisk/keys/"*

docker compose -f "$HERE/docker-compose.yml" up -d
cleanup() {
  status=$?
  if [[ $status -ne 0 ]]; then
    docker compose -f "$HERE/docker-compose.yml" logs --tail 200 asterisk || true
    docker compose -f "$HERE/docker-compose.yml" logs --tail 50 coturn || true
  fi
  docker compose -f "$HERE/docker-compose.yml" down || true
  exit $status
}
trap cleanup EXIT
for i in $(seq 1 60); do
  if docker compose -f "$HERE/docker-compose.yml" exec -T asterisk asterisk -rx "pjsip show transports" 2>/dev/null | grep -q transport-tls; then
    break
  fi
  sleep 2
done
docker compose -f "$HERE/docker-compose.yml" exec -T asterisk asterisk -rx "pjsip show transports" || true
docker compose -f "$HERE/docker-compose.yml" exec -T asterisk asterisk -rx "pjsip show endpoints" || true

docker compose -f "$HERE/docker-compose.yml" logs --tail 20 coturn || true

export BSK_TEST_CA_PEM="$HERE/asterisk/keys/asterisk.pem"
if ! BSK_TEST_VERBOSE=1 "$BUILD/tests/bsk_test_integration" "$HOSTIP" 2> "$BUILD/integration.err"; then
  grep -E "CHECK failed|integration: call|^integration \[[0-9]/1\] (TX|RX)|^SIP/2.0|^(INVITE|BYE|ACK|CANCEL|REGISTER|INFO) sip" "$BUILD/integration.err" | tail -80 || true
  grep -iE "warn|error|fail" "$BUILD/integration.err" | tail -30 || true
  exit 1
fi
grep -E "integration: call" "$BUILD/integration.err" | tail -40 || true

if ! BSK_TEST_VERBOSE=1 "$BUILD/tests/bsk_test_integration" "$HOSTIP" relay 2> "$BUILD/integration-relay.err"; then
  grep -E "CHECK failed|integration: call|ice|turn|TURN" "$BUILD/integration-relay.err" | tail -60 || true
  docker compose -f "$HERE/docker-compose.yml" logs --tail 60 coturn || true
  exit 1
fi
