#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBX="$ROOT/Tests/Integration"
KEYS="$PBX/asterisk/keys"
TURN_CONFIG="$PBX/coturn/turnserver.conf"
DEV_TURN_CONFIG="$PBX/coturn/turnserver.dev.conf"
TURN_USER=bsk
COMPOSE=(docker compose -f "$PBX/docker-compose.yml" -f "$PBX/docker-compose.dev.yml")
READY_ATTEMPTS=60

usage() {
  cat <<EOF
Usage: Scripts/dev-pbx.sh start|stop|status|logs

Runs the Asterisk and coturn setup of the integration tests for manual testing with the
sample app on a phone in the same network. Set HOSTIP to choose the address; otherwise the
first address of the computer is used.
EOF
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

certificate_matches() {
  [[ -f "$KEYS/asterisk.pem" ]] &&
    openssl x509 -in "$KEYS/asterisk.pem" -noout -text 2>/dev/null | grep -qE "IP Address:$1(,|$)"
}

ensure_certificate() {
  local ip="$1"
  mkdir -p "$KEYS"
  chmod 755 "$KEYS"
  if ! certificate_matches "$ip"; then
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
      -keyout "$KEYS/asterisk.key" -out "$KEYS/asterisk.pem" -days 30 \
      -subj "/CN=baresipkit-dev" -addext "subjectAltName=IP:$ip" >/dev/null 2>&1
  fi
  chmod 644 "$KEYS/"*
}

ensure_turn_config() {
  if [[ ! -f "$DEV_TURN_CONFIG" ]]; then
    local password
    password="$(openssl rand -hex 12)"
    grep -v -e '^allow-loopback-peers$' -e '^user=' "$TURN_CONFIG" > "$DEV_TURN_CONFIG"
    printf 'user=%s:%s\n' "$TURN_USER" "$password" >> "$DEV_TURN_CONFIG"
    chmod 644 "$DEV_TURN_CONFIG"
  fi
}

turn_password() {
  sed -n "s/^user=$TURN_USER://p" "$DEV_TURN_CONFIG"
}

wait_until_ready() {
  for _ in $(seq 1 "$READY_ATTEMPTS"); do
    if "${COMPOSE[@]}" exec -T asterisk asterisk -rx "pjsip show transports" 2>/dev/null | grep -q transport-tls; then
      return 0
    fi
    sleep 2
  done
  echo "Asterisk did not start; see Scripts/dev-pbx.sh logs" >&2
  return 1
}

print_settings() {
  local ip="$1"
  cat <<EOF

Asterisk and coturn are running on $ip.

Sample app, Account screen:
  Domain           $ip
  Transport, port  TLS 5061 (or UDP 5060)
  Users            alice / alicepass, bob / bobpass
  Server CA        $KEYS/asterisk.pem (send it to the phone and import it)
  TURN             turn:$ip:3478 or turns:$ip:5349, user $TURN_USER / $(turn_password)

Numbers to call:
  echo             answers and plays your audio and video back
  early            sends 183 early media for 3 seconds, then answers like echo
  alice, bob       calls the other account, for example on a second phone

The certificate is valid for $ip only; run start again after the address changes.
The TURN password is new after every stop. The SIP passwords are fixed test values:
use this server in a network you trust only.
EOF
}

case "${1:-}" in
  start)
    ip="$(host_ip)"
    ensure_certificate "$ip"
    ensure_turn_config
    "${COMPOSE[@]}" up -d
    wait_until_ready
    print_settings "$ip"
    ;;
  stop)
    "${COMPOSE[@]}" down
    rm -f "$DEV_TURN_CONFIG"
    ;;
  status)
    "${COMPOSE[@]}" ps
    "${COMPOSE[@]}" exec -T asterisk asterisk -rx "pjsip show contacts" || true
    ;;
  logs)
    "${COMPOSE[@]}" logs -f asterisk coturn
    ;;
  *)
    usage
    exit 1
    ;;
esac
