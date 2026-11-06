#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PREFIX="${PREFIX:?set PREFIX to a host build prefix}"
BUILD="${BUILD_DIR:-$ROOT/Build/out/host/core-tests}"
HOSTIP="${HOSTIP:?set HOSTIP to the address Asterisk is reachable on}"

mkdir -p "$HERE/asterisk/keys"
if [[ ! -f "$HERE/asterisk/keys/asterisk.pem" ]]; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$HERE/asterisk/keys/asterisk.key" -out "$HERE/asterisk/keys/asterisk.pem" -days 30 \
    -subj "/CN=asterisk" -addext "subjectAltName=IP:$HOSTIP" >/dev/null 2>&1
fi

docker compose -f "$HERE/docker-compose.yml" up -d
trap 'docker compose -f "$HERE/docker-compose.yml" down' EXIT
sleep 5

export BSK_TEST_CA_PEM="$HERE/asterisk/keys/asterisk.pem"
"$BUILD/tests/bsk_test_integration" "$HOSTIP"
