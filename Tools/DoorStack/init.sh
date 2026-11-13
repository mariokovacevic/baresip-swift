#!/bin/sh
set -eu

STATE=/state
HOSTIP="${HOSTIP:-127.0.0.1}"
mkdir -p "$STATE/asterisk/keys"

if [ ! -f "$STATE/secrets.env" ]; then
  {
    echo "RESIDENT_PASSWORD=$(openssl rand -hex 12)"
    echo "DOOR_PASSWORD=$(openssl rand -hex 12)"
    echo "AMI_SECRET=$(openssl rand -hex 16)"
  } > "$STATE/secrets.env"
fi
. "$STATE/secrets.env"

certificate_names() {
  openssl x509 -in "$1" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1
}

KEYS="$STATE/asterisk/keys"
if [ ! -f "$KEYS/asterisk.pem" ] || ! certificate_names "$KEYS/asterisk.pem" | grep -q "IP Address:$HOSTIP\(,\|$\)"; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$KEYS/asterisk.key" -out "$KEYS/asterisk.pem" -days 30 \
    -subj "/CN=baresipkit-doorstack" -addext "subjectAltName=IP:$HOSTIP" >/dev/null 2>&1
fi

if [ ! -f "$STATE/apns-mock.pem" ]; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$STATE/apns-mock.key" -out "$STATE/apns-mock.pem" -days 365 \
    -subj "/CN=apns-mock" -addext "subjectAltName=IP:127.0.0.1,DNS:localhost" >/dev/null 2>&1
fi

cat > "$STATE/asterisk/pjsip_secrets.conf" <<CONF
[100](auth-template)
username=100
password=$RESIDENT_PASSWORD
[101](auth-template)
username=101
password=$RESIDENT_PASSWORD
[door1](auth-template)
username=door1
password=$DOOR_PASSWORD
CONF

# Behind Docker Desktop's published ports (docker-compose.desktop.yml) phones and simulators arrive
# from the network's gateway: they get EXTERNAL_ADDRESS in Contact and SDP, and anything in
# LOCAL_NET, the door station, gets the PBX's own address. Empty elsewhere.
: > "$STATE/asterisk/pjsip_nat.conf"
if [ -n "${EXTERNAL_ADDRESS:-}" ]; then
  for transport in transport-udp transport-tcp transport-tls; do
    {
      echo "[$transport](+)"
      echo "external_signaling_address=$EXTERNAL_ADDRESS"
      echo "external_media_address=$EXTERNAL_ADDRESS"
      for net in $LOCAL_NET; do
        echo "local_net=$net"
      done
    } >> "$STATE/asterisk/pjsip_nat.conf"
  done
fi

cat > "$STATE/asterisk/manager_secrets.conf" <<CONF
[bsk-push]
secret=$AMI_SECRET
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.255
read=user
write=
CONF

chmod 755 "$STATE" "$STATE/asterisk" "$KEYS"
chmod 644 "$STATE/secrets.env" "$STATE/apns-mock.pem" "$STATE/apns-mock.key" \
  "$KEYS/asterisk.pem" "$KEYS/asterisk.key" \
  "$STATE/asterisk/pjsip_secrets.conf" "$STATE/asterisk/manager_secrets.conf" \
  "$STATE/asterisk/pjsip_nat.conf"

echo "door stack state ready for $HOSTIP"
