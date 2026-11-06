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

if [[ "$(uname -s)" == Darwin ]]; then
  if [[ -n "${BUILD_ONLY:-}" ]]; then
  echo "built test binaries in $BUILD/tests"
  exit 0
fi

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

echo "== registration failure (wrong password)"
REGISTRAR_HOST="$HOSTIP" REGISTRAR_IDLE_TIMEOUT=4 python3 "$ROOT/Tools/ContactParameterProof/fake_registrar.py" "$BUILD/trace-badpass.txt" >/dev/null &
REG_PID=$!
sleep 0.5
"$BUILD/tests/bsk_test_registration" "$HOSTIP" 5080 badpass
wait "$REG_PID"

echo "== registration over TLS (private CA in memory, pinning ok/bad, missing CA)"
CERT_DIR="$BUILD/tls"
mkdir -p "$CERT_DIR"
if [[ ! -f "$CERT_DIR/cert.pem" ]]; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.pem" -days 2 \
    -subj "/CN=baresipkit-test" -addext "subjectAltName=IP:$HOSTIP" >/dev/null 2>&1
fi
PIN="$(openssl x509 -in "$CERT_DIR/cert.pem" -pubkey -noout | openssl pkey -pubin -outform der 2>/dev/null | openssl dgst -sha256 -binary | base64)"
export BSK_TEST_CA_PEM="$CERT_DIR/cert.pem"
export BSK_TEST_PIN="$PIN"
for mode in tls tls-pin-ok tls-pin-bad tls-noca; do
  REGISTRAR_HOST="$HOSTIP" REGISTRAR_PORT=5081 REGISTRAR_IDLE_TIMEOUT=5 python3 "$ROOT/Tools/ContactParameterProof/tls_registrar.py" \
    "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem" "$BUILD/trace-$mode.txt" > "$BUILD/registrar-$mode.out" &
  REG_PID=$!
  sleep 0.7
  "$BUILD/tests/bsk_test_registration" "$HOSTIP" 5081 "$mode"
  wait "$REG_PID"
  cat "$BUILD/registrar-$mode.out"
done

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

echo "== two-process call with ICE (host candidates, selected pair in statistics, ICE restart)"
"$BUILD/tests/bsk_test_call" callee "$HOSTIP" ice > "$BUILD/callee-ice.out" 2> "$BUILD/callee-ice.err" &
CALLEE_PID=$!
for i in $(seq 1 50); do
  grep -q READY "$BUILD/callee-ice.out" 2>/dev/null && break
  sleep 0.1
done
"$BUILD/tests/bsk_test_call" caller "$HOSTIP" ice 2> "$BUILD/caller-ice.err"
wait "$CALLEE_PID"
cat "$BUILD/callee-ice.out"

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
  BSK_TEST_VCODEC=H264 "$BUILD/tests/bsk_test_video" caller "$HOSTIP" 2> "$BUILD/h264caller.err"
  wait "$VCALLEE_PID"
  cat "$BUILD/h264callee.out"
fi

echo "ALL CORE TESTS PASSED"
