#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$HERE/state"
CONTROL=http://127.0.0.1:8089
GATEWAY=http://127.0.0.1:8088
READY_ATTEMPTS=120

usage() {
  cat <<USAGE
Usage: Tools/DoorStack/doorstack.sh start|stop|status|ring [resident]|test|logs [service]

Runs a PBX, a push gateway, stand-ins for Apple's and Google's push services and a door station
simulator for trying the sample apps as an intercom. Set HOSTIP to choose the address the phone reaches
this computer at; otherwise the first address of the computer is used.
USAGE
}

host_ip() {
  if [[ -n "${HOSTIP:-}" ]]; then
    echo "$HOSTIP"
  elif command -v ipconfig >/dev/null && ipconfig getifaddr en0 >/dev/null 2>&1; then
    ipconfig getifaddr en0
  else
    hostname -I | awk '{print $1}'
  fi
}

compose() {
  local files=(-f "$HERE/docker-compose.yml")
  if [[ "$(uname)" == Darwin ]]; then
    # Docker Desktop: published ports on a bridge network; see docker-compose.desktop.yml.
    files+=(-f "$HERE/docker-compose.desktop.yml")
    export PBX_ADDRESS="${PBX_ADDRESS:-172.30.0.10}"
    export EXTERNAL_ADDRESS="${EXTERNAL_ADDRESS:-$(host_ip)}"
    export LOCAL_NET="${LOCAL_NET:-$PBX_ADDRESS/32}"
  fi
  HOSTIP="$(host_ip)" docker compose "${files[@]}" "$@"
}

secret() {
  sed -n "s/^$1=//p" "$STATE/secrets.env" 2>/dev/null
}

wait_for_door() {
  for _ in $(seq 1 "$READY_ATTEMPTS"); do
    if curl -fsS "$CONTROL/status" 2>/dev/null | grep -q '"registered": true'; then
      return 0
    fi
    sleep 0.5
  done
  echo "the door station did not register; see: Tools/DoorStack/doorstack.sh logs" >&2
  return 1
}

wait_for_gateway() {
  for _ in $(seq 1 "$READY_ATTEMPTS"); do
    if curl -fsS "$GATEWAY/health" 2>/dev/null | grep -q '"ami": true'; then
      return 0
    fi
    sleep 0.5
  done
  echo "the push gateway did not connect to the PBX; see: Tools/DoorStack/doorstack.sh logs" >&2
  return 1
}

status() {
  local ip
  ip="$(host_ip)"
  cat <<STATUS
PBX            $ip, SIP over UDP and TCP on 5060, TLS on 5061
CA for TLS     $STATE/asterisk/keys/asterisk.pem
Residents      100 and 101, password $(secret RESIDENT_PASSWORD)
Door station   door1, door code ${DOOR_CODE:-1234}
Push gateway   $(curl -fsS "$GATEWAY/health" 2>/dev/null || echo "not running")
Door           $(curl -fsS "$CONTROL/status" 2>/dev/null || echo "not running")
STATUS
}

case "${1:-}" in
  start)
    compose up -d --build
    wait_for_door
    wait_for_gateway
    status
    ;;
  stop)
    compose down
    ;;
  status)
    status
    ;;
  ring)
    curl -fsS -X POST "$CONTROL/ring?to=${2:-100}"
    echo
    ;;
  test)
    compose up -d --build
    wait_for_door
    wait_for_gateway
    compose run --rm phone-sim
    compose run --rm -e PUSH_PLATFORM=firebase phone-sim
    ;;
  logs)
    shift
    compose logs -f "$@"
    ;;
  *)
    usage
    exit 2
    ;;
esac
