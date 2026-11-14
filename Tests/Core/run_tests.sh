#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PREFIX="${PREFIX:?set PREFIX to a host build prefix (Build/out/host/prefix)}"
PREFIX="$(cd "$PREFIX" && pwd)"
BUILD="${BUILD_DIR:-$ROOT/Build/out/host/core-tests}"
SANITIZE="${SANITIZE:-address,undefined}"
HOSTIP="${HOSTIP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
if [[ -z "$HOSTIP" && "$(uname -s)" == Darwin ]]; then
  HOSTIP="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi
HOSTIP="${HOSTIP:-127.0.0.1}"

EXTRA="$PREFIX/lib/libopus.a;$PREFIX/lib/libssl.a;$PREFIX/lib/libcrypto.a;z;resolv;pthread;m;dl"
if [[ -f "$PREFIX/lib/libvpx.a" ]]; then
  EXTRA="$PREFIX/lib/libvpx.a;$EXTRA"
fi
FLAGS=""
if [[ -n "$SANITIZE" ]]; then
  FLAGS="-fsanitize=$SANITIZE -fno-omit-frame-pointer"
fi

cmake -S "$ROOT/Core" -B "$BUILD" -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DBARESIP_INCLUDE_DIR="$PREFIX/include/baresip" \
  -DBARESIP_LIBRARY="$PREFIX/lib/libbaresip.a" \
  -DBARESIPKIT_EXTRA_LIBS="$EXTRA" \
  -DBARESIPKIT_BUILD_TESTS=ON \
  -DCMAKE_C_FLAGS="$FLAGS" -DCMAKE_EXE_LINKER_FLAGS="$FLAGS" >/dev/null
cmake --build "$BUILD" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)" >/dev/null

if [[ -n "${BUILD_ONLY:-}" ]]; then
  echo "built test binaries in $BUILD/tests"
  exit 0
fi

if [[ "$(uname -s)" == Darwin ]]; then
  export ASAN_OPTIONS="${ASAN_OPTIONS:-detect_leaks=0}"
else
  export ASAN_OPTIONS="${ASAN_OPTIONS:-detect_leaks=1}"
fi
export UBSAN_OPTIONS="${UBSAN_OPTIONS:-print_stacktrace=1}"

echo "== unit"
"$BUILD/tests/bsk_test_unit"

echo "== registration (fake registrar on $HOSTIP:5080)"
TRACE="$BUILD/trace-registration.txt"
REGISTRAR_HOST="$HOSTIP" REGISTRAR_IDLE_TIMEOUT=8 python3 "$ROOT/Tools/ContactParameterProof/fake_registrar.py" "$TRACE" >/dev/null &
REG_PID=$!
sleep 0.5
"$BUILD/tests/bsk_test_registration" "$HOSTIP" 5080 ok
wait "$REG_PID"
python3 "$ROOT/Tools/ContactParameterProof/verify_trace.py" "$TRACE" "A,A,B,B,B0"

echo "== registration while a REGISTER is unanswered (slow registrar keeps the binding of the client)"
for mode in reregister overlap; do
  token="pn-tok=0000"
  [[ "$mode" == overlap ]] && token="pn-tok=4444"
  REGISTRAR_IDLE_TIMEOUT=4 python3 -I "$HERE/slow_registrar.py" "$HOSTIP" 5080 "$token" > "$BUILD/registrar-$mode.out" &
  REG_PID=$!
  sleep 0.5
  "$BUILD/tests/bsk_test_registration" "$HOSTIP" 5080 "$mode"
  wait "$REG_PID" || { cat "$BUILD/registrar-$mode.out"; exit 1; }
  cat "$BUILD/registrar-$mode.out"
done

echo "== registration failure (wrong password)"
REGISTRAR_HOST="$HOSTIP" REGISTRAR_IDLE_TIMEOUT=4 python3 "$ROOT/Tools/ContactParameterProof/fake_registrar.py" "$BUILD/trace-badpass.txt" >/dev/null &
REG_PID=$!
sleep 0.5
"$BUILD/tests/bsk_test_registration" "$HOSTIP" 5080 badpass
wait "$REG_PID"

echo "== registration over TLS (private CA in memory, registrar without a transport, CA bundle, pinning ok/bad, missing CA)"
CERT_DIR="$BUILD/tls"
mkdir -p "$CERT_DIR"
if [[ ! -f "$CERT_DIR/cert.pem" ]]; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.pem" -days 2 \
    -subj "/CN=baresipkit-test" -addext "subjectAltName=IP:$HOSTIP" >/dev/null 2>&1
fi
PIN="$(openssl x509 -in "$CERT_DIR/cert.pem" -pubkey -noout | openssl pkey -pubin -outform der 2>/dev/null | openssl dgst -sha256 -binary | base64)"
if [[ ! -f "$CERT_DIR/other.pem" ]]; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$CERT_DIR/other-key.pem" -out "$CERT_DIR/other.pem" -days 2 \
    -subj "/CN=baresipkit-other" >/dev/null 2>&1
fi
cat "$CERT_DIR/other.pem" "$CERT_DIR/cert.pem" > "$CERT_DIR/bundle.pem"
cat "$CERT_DIR/cert.pem" "$CERT_DIR/other.pem" > "$CERT_DIR/appended.pem"
export BSK_TEST_PIN="$PIN"
BSK_TEST_PIN_APPENDED="$(openssl x509 -in "$CERT_DIR/other.pem" -pubkey -noout | openssl pkey -pubin -outform der 2>/dev/null | openssl dgst -sha256 -binary | base64)"
export BSK_TEST_PIN_APPENDED
for mode in tls tls-bare tls-bundle tls-pin-ok tls-pin-bad tls-noca; do
  export BSK_TEST_CA_PEM="$CERT_DIR/cert.pem"
  if [[ "$mode" == tls-bundle ]]; then
    export BSK_TEST_CA_PEM="$CERT_DIR/bundle.pem"
  fi
  REGISTRAR_HOST="$HOSTIP" REGISTRAR_PORT=5081 REGISTRAR_IDLE_TIMEOUT=5 python3 "$ROOT/Tools/ContactParameterProof/tls_registrar.py" \
    "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem" "$BUILD/trace-$mode.txt" > "$BUILD/registrar-$mode.out" &
  REG_PID=$!
  sleep 0.7
  "$BUILD/tests/bsk_test_registration" "$HOSTIP" 5081 "$mode"
  wait "$REG_PID"
  cat "$BUILD/registrar-$mode.out"
done

if [[ "$(uname -s)" != Darwin ]]; then
  echo "== registration over TLS with the system trust store (no CA configured, pinning ok/bad, a pinned certificate appended to the chain)"
  for mode in tls-system tls-system-pin-ok tls-system-pin-bad tls-system-pin-appended; do
    CHAIN="$CERT_DIR/cert.pem"
    [[ "$mode" == tls-system-pin-appended ]] && CHAIN="$CERT_DIR/appended.pem"
    REGISTRAR_HOST="$HOSTIP" REGISTRAR_PORT=5081 REGISTRAR_IDLE_TIMEOUT=5 python3 "$ROOT/Tools/ContactParameterProof/tls_registrar.py" \
      "$CHAIN" "$CERT_DIR/key.pem" "$BUILD/trace-$mode.txt" > "$BUILD/registrar-$mode.out" &
    REG_PID=$!
    sleep 0.7
    SSL_CERT_FILE="$CERT_DIR/cert.pem" "$BUILD/tests/bsk_test_registration" "$HOSTIP" 5081 "$mode"
    wait "$REG_PID"
    cat "$BUILD/registrar-$mode.out"
  done
fi

echo "== system trust store accepts a public server chain and rejects other names"
TRUST_DIR="$BUILD/trust"
TRUST_HOST="${BSK_TEST_TRUST_HOST:-example.com}"
rm -rf "$TRUST_DIR"
mkdir -p "$TRUST_DIR"
fetch_chain() {
  if command -v timeout >/dev/null; then
    timeout 20 openssl s_client -connect "$TRUST_HOST:443" -servername "$TRUST_HOST" -showcerts </dev/null 2>/dev/null
  else
    openssl s_client -connect "$TRUST_HOST:443" -servername "$TRUST_HOST" -showcerts </dev/null 2>/dev/null
  fi
}
fetch_chain | awk -v dir="$TRUST_DIR" '/BEGIN CERTIFICATE/ { n++ } n { print > sprintf("%s/cert-%d.pem", dir, n) }' || true
for pem in "$TRUST_DIR"/cert-*.pem; do
  [[ -e "$pem" ]] || continue
  openssl x509 -in "$pem" -outform der -out "${pem%.pem}.der" 2>/dev/null || rm -f "${pem%.pem}.der"
done
if [[ -f "$TRUST_DIR/cert-1.der" ]]; then
  if [[ "$(uname -s)" != Darwin && -z "${SSL_CERT_FILE:-}" && -f /etc/ssl/certs/ca-certificates.crt ]]; then
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt "$BUILD/tests/bsk_test_trust" "$TRUST_HOST" "$TRUST_DIR"/cert-*.der
  else
    "$BUILD/tests/bsk_test_trust" "$TRUST_HOST" "$TRUST_DIR"/cert-*.der
  fi
elif [[ "$(uname -s)" == Darwin && -n "${CI:-}" && -z "${BSK_TEST_TRUST_OPTIONAL:-}" ]]; then
  echo "trust: no chain from $TRUST_HOST, so SecTrust was not exercised; set BSK_TEST_TRUST_OPTIONAL=1 to allow that" >&2
  exit 1
else
  echo "trust: skipped (no chain from $TRUST_HOST; no route to a public TLS server)"
fi
if [[ "$(uname -s)" != Darwin ]]; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$TRUST_DIR/root.key" -out "$TRUST_DIR/root.pem" -days 2 -subj "/CN=baresipkit-test-root" \
    -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign" >/dev/null 2>&1
  openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$TRUST_DIR/leaf.key" -out "$TRUST_DIR/leaf.csr" -subj "/CN=sip.example.com" >/dev/null 2>&1
  printf 'subjectAltName=DNS:sip.example.com\nextendedKeyUsage=serverAuth\n' > "$TRUST_DIR/leaf.cnf"
  openssl x509 -req -in "$TRUST_DIR/leaf.csr" -CA "$TRUST_DIR/root.pem" -CAkey "$TRUST_DIR/root.key" \
    -CAcreateserial -out "$TRUST_DIR/leaf.pem" -days 2 -extfile "$TRUST_DIR/leaf.cnf" >/dev/null 2>&1
  openssl x509 -in "$TRUST_DIR/leaf.pem" -outform der -out "$TRUST_DIR/leaf.der"
  openssl x509 -in "$TRUST_DIR/root.pem" -outform der -out "$TRUST_DIR/root.der"
  SSL_CERT_FILE="$TRUST_DIR/root.pem" "$BUILD/tests/bsk_test_trust" sip.example.com "$TRUST_DIR/leaf.der" "$TRUST_DIR/root.der"
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$TRUST_DIR/pinned.key" -out "$TRUST_DIR/pinned.pem" -days 2 -subj "/CN=pinned.example.com" >/dev/null 2>&1
  openssl x509 -in "$TRUST_DIR/pinned.pem" -outform der -out "$TRUST_DIR/pinned.der"
  SSL_CERT_FILE="$TRUST_DIR/root.pem" "$BUILD/tests/bsk_test_trust" --unvisited sip.example.com \
    "$TRUST_DIR/leaf.der" "$TRUST_DIR/root.der" "$TRUST_DIR/pinned.der"
fi

echo "== two-process call (hold/resume, DTMF, mute, stats)"
"$BUILD/tests/bsk_test_call" callee "$HOSTIP" > "$BUILD/callee.out" 2> "$BUILD/callee.err" &
CALLEE_PID=$!
for i in $(seq 1 50); do
  grep -q READY "$BUILD/callee.out" 2>/dev/null && break
  sleep 0.1
done
"$BUILD/tests/bsk_test_call" caller "$HOSTIP" 2> "$BUILD/caller.err"
wait "$CALLEE_PID"
cat "$BUILD/callee.out"

echo "== session timer (RFC 4028): the caller refreshes every second, the call stays up for 6 seconds"
BSK_TEST_VERBOSE=1 BSK_TEST_SESSION_EXPIRES=2 "$BUILD/tests/bsk_test_call" peer "$HOSTIP" > "$BUILD/callee-timer.out" 2> "$BUILD/callee-timer.err" &
CALLEE_PID=$!
for i in $(seq 1 50); do
  grep -q READY "$BUILD/callee-timer.out" 2>/dev/null && break
  sleep 0.1
done
BSK_TEST_VERBOSE=1 BSK_TEST_SESSION_EXPIRES=2 "$BUILD/tests/bsk_test_call" caller "$HOSTIP" 2> "$BUILD/caller-timer.err"
wait "$CALLEE_PID"
REQUESTS=$(grep -cE '^(INVITE|UPDATE) sip:bob@' "$BUILD/callee-timer.err" || true)
REFRESHES=$((REQUESTS - 1))
echo "refresh requests seen by the callee: $REFRESHES"
if (( REFRESHES < 3 )); then
  echo "expected at least 3 session refreshes" >&2
  exit 1
fi

echo "== session timer: 422 below Min-SE, an INVITE with Require: timer is answered (scripted caller)"
BSK_TEST_SESSION_EXPIRES=1800 BSK_TEST_SESSION_MIN_SE=90 "$BUILD/tests/bsk_test_call" peer "$HOSTIP" > "$BUILD/peer-timer.out" 2> "$BUILD/peer-timer.err" &
CALLEE_PID=$!
for i in $(seq 1 50); do
  grep -q READY "$BUILD/peer-timer.out" 2>/dev/null && break
  sleep 0.1
done
if ! python3 -I "$HERE/sip_peer.py" require-timer "$HOSTIP" 5070; then
  kill "$CALLEE_PID" 2>/dev/null || true
  exit 1
fi
wait "$CALLEE_PID"
cat "$BUILD/peer-timer.out"

echo "== call before the audio session is active (stays up, no microphone until activation)"
"$BUILD/tests/bsk_test_call" peer "$HOSTIP" > "$BUILD/peer-inactive.out" 2> "$BUILD/peer-inactive.err" &
CALLEE_PID=$!
for i in $(seq 1 50); do
  grep -q READY "$BUILD/peer-inactive.out" 2>/dev/null && break
  sleep 0.1
done
"$BUILD/tests/bsk_test_call" caller-inactive "$HOSTIP" 2> "$BUILD/caller-inactive.err"
wait "$CALLEE_PID"
cat "$BUILD/peer-inactive.out"

echo "== receive-only preview opens the NAT pinhole (empty RTP on the wire, none without it); X-Device-ID kept"
for pinhole in on off; do
  if [[ "$pinhole" == off ]]; then export BSK_TEST_NO_PINHOLE=1; fi
  "$BUILD/tests/bsk_test_call" previewer "$HOSTIP" > "$BUILD/previewer-$pinhole.out" 2> "$BUILD/previewer-$pinhole.err" &
  CALLEE_PID=$!
  for i in $(seq 1 50); do
    grep -q READY "$BUILD/previewer-$pinhole.out" 2>/dev/null && break
    sleep 0.1
  done
  if [[ "$pinhole" == on ]]; then
    python3 -I "$HERE/pinhole_uac.py" "$HOSTIP" 5070
  elif python3 -I "$HERE/pinhole_uac.py" "$HOSTIP" 5070; then
    echo "pinhole packets arrived although the pinhole is off" >&2
    exit 1
  else
    echo "pinhole off: no packets, as expected"
  fi
  wait "$CALLEE_PID"
  grep -v READY "$BUILD/previewer-$pinhole.out" || true
  unset BSK_TEST_NO_PINHOLE
done

echo "== two-process call with ICE and G.722 (host candidates, selected pair in statistics, ICE restart)"
export BSK_TEST_ACODEC="G722/16000/1"
"$BUILD/tests/bsk_test_call" callee "$HOSTIP" ice > "$BUILD/callee-ice.out" 2> "$BUILD/callee-ice.err" &
CALLEE_PID=$!
for i in $(seq 1 50); do
  grep -q READY "$BUILD/callee-ice.out" 2>/dev/null && break
  sleep 0.1
done
"$BUILD/tests/bsk_test_call" caller "$HOSTIP" ice 2> "$BUILD/caller-ice.err"
wait "$CALLEE_PID"
cat "$BUILD/callee-ice.out"
unset BSK_TEST_ACODEC

echo "== SIP MESSAGE and attended transfer (three processes)"
"$BUILD/tests/bsk_test_transfer" b "$HOSTIP" > "$BUILD/xfer-b.out" 2> "$BUILD/xfer-b.err" &
XB_PID=$!
"$BUILD/tests/bsk_test_transfer" c "$HOSTIP" > "$BUILD/xfer-c.out" 2> "$BUILD/xfer-c.err" &
XC_PID=$!
for i in $(seq 1 50); do
  grep -q READY "$BUILD/xfer-b.out" 2>/dev/null && grep -q READY "$BUILD/xfer-c.out" 2>/dev/null && break
  sleep 0.1
done
if ! "$BUILD/tests/bsk_test_transfer" a "$HOSTIP" 2> "$BUILD/xfer-a.err"; then
  grep -E "CHECK|state" "$BUILD/xfer-a.err" | tail -20 || true
  kill "$XB_PID" "$XC_PID" 2>/dev/null || true
  grep -E "CHECK|state" "$BUILD/xfer-b.err" "$BUILD/xfer-c.err" | tail -30 || true
  exit 1
fi
XB_RC=0
XC_RC=0
wait "$XB_PID" || XB_RC=$?
wait "$XC_PID" || XC_RC=$?
cat "$BUILD/xfer-b.out" "$BUILD/xfer-c.out" | grep -v READY || true
if [[ "$XB_RC" != 0 || "$XC_RC" != 0 ]]; then
  grep -E "CHECK|state" "$BUILD/xfer-b.err" "$BUILD/xfer-c.err" | tail -40 || true
  exit 1
fi

echo "== scripted peer: REFER while ringing, forged replace, calls into the engine from callbacks, teardown with a live call, CANCEL with a Reason"
for scenario in refer-ringing fake-replace reentrant remove-live stop-live cancel-elsewhere; do
  "$BUILD/tests/bsk_test_security" "$scenario" "$HOSTIP" > "$BUILD/security-$scenario.out" 2> "$BUILD/security-$scenario.err" &
  VICTIM_PID=$!
  for i in $(seq 1 50); do
    grep -q READY "$BUILD/security-$scenario.out" 2>/dev/null && break
    sleep 0.1
  done
  if ! python3 -I "$HERE/sip_peer.py" "$scenario" "$HOSTIP" 5090; then
    kill "$VICTIM_PID" 2>/dev/null || true
    tail -40 "$BUILD/security-$scenario.err" || true
    exit 1
  fi
  if ! wait "$VICTIM_PID"; then
    tail -40 "$BUILD/security-$scenario.err" || true
    exit 1
  fi
  grep -v READY "$BUILD/security-$scenario.out" || true
done

if [[ -f "$PREFIX/lib/libvpx.a" ]]; then
  echo "== video preview (fakevideo)"
  "$BUILD/tests/bsk_test_video" preview
  echo "== two-process video call (VP8, local and remote frame sinks)"
  "$BUILD/tests/bsk_test_video" callee "$HOSTIP" > "$BUILD/vcallee.out" 2> "$BUILD/vcallee.err" &
  VCALLEE_PID=$!
  for i in $(seq 1 50); do
    grep -q READY "$BUILD/vcallee.out" 2>/dev/null && break
    sleep 0.1
  done
  "$BUILD/tests/bsk_test_video" caller "$HOSTIP" 2> "$BUILD/vcaller.err"
  wait "$VCALLEE_PID"
  cat "$BUILD/vcallee.out"
else
  echo "== video stages skipped (no libvpx in prefix; build with MODULE_SET=full)"
fi

if [[ "$(uname -s)" == Darwin ]]; then
  echo "== two-process H.264 video call (VideoToolbox encode/decode)"
  BSK_TEST_VCODEC=H264 "$BUILD/tests/bsk_test_video" callee "$HOSTIP" > "$BUILD/h264callee.out" 2> "$BUILD/h264callee.err" &
  VCALLEE_PID=$!
  for i in $(seq 1 50); do
    grep -q READY "$BUILD/h264callee.out" 2>/dev/null && break
    sleep 0.1
  done
  if ! BSK_TEST_VCODEC=H264 "$BUILD/tests/bsk_test_video" caller "$HOSTIP" 2> "$BUILD/h264caller.err"; then
    grep -E "CHECK|vidtoolbox|video" "$BUILD/h264caller.err" | tail -40 || true
    kill "$VCALLEE_PID" 2>/dev/null || true
    exit 1
  fi
  wait "$VCALLEE_PID"
  cat "$BUILD/h264callee.out"

  echo "== camera-only call receives the callee's video (no audio, our camera stays off)"
  BSK_TEST_VCODEC=H264 BSK_TEST_AUDIO_CALLER=1 "$BUILD/tests/bsk_test_video" callee "$HOSTIP" > "$BUILD/acallee.out" 2> "$BUILD/acallee.err" &
  VCALLEE_PID=$!
  for i in $(seq 1 50); do
    grep -q READY "$BUILD/acallee.out" 2>/dev/null && break
    sleep 0.1
  done
  if ! BSK_TEST_VCODEC=H264 "$BUILD/tests/bsk_test_video" acaller "$HOSTIP" 2> "$BUILD/acaller.err"; then
    grep -E "CHECK|video" "$BUILD/acaller.err" | tail -40 || true
    kill "$VCALLEE_PID" 2>/dev/null || true
    exit 1
  fi
  if ! wait "$VCALLEE_PID"; then
    grep -E "CHECK" "$BUILD/acallee.err" | tail -20 || true
    exit 1
  fi
  grep -v READY "$BUILD/acallee.out"

  echo "== preview, then answer without the camera (the camera stays off)"
  BSK_TEST_VCODEC=H264 BSK_TEST_PREVIEW_NO_CAMERA=1 "$BUILD/tests/bsk_test_video" callee "$HOSTIP" > "$BUILD/pcallee.out" 2> "$BUILD/pcallee.err" &
  VCALLEE_PID=$!
  for i in $(seq 1 50); do
    grep -q READY "$BUILD/pcallee.out" 2>/dev/null && break
    sleep 0.1
  done
  if ! BSK_TEST_VCODEC=H264 "$BUILD/tests/bsk_test_video" pcaller "$HOSTIP" 2> "$BUILD/pcaller.err"; then
    grep -E "CHECK" "$BUILD/pcaller.err" | tail -20 || true
    kill "$VCALLEE_PID" 2>/dev/null || true
    exit 1
  fi
  if ! wait "$VCALLEE_PID"; then
    grep -E "CHECK" "$BUILD/pcallee.err" | tail -20 || true
    exit 1
  fi
  grep -v READY "$BUILD/pcallee.out"
fi

echo "ALL CORE TESTS PASSED"
