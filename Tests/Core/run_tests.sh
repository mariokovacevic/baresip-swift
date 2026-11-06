#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PREFIX="${PREFIX:?set PREFIX to a host build prefix (Build/out/host/prefix)}"
BUILD="${BUILD_DIR:-$ROOT/Build/out/host/core-tests}"
SANITIZE="${SANITIZE:-address,undefined}"
HOSTIP="${HOSTIP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
HOSTIP="${HOSTIP:-127.0.0.1}"

EXTRA="$PREFIX/lib/libopus.a;$PREFIX/lib/libssl.a;$PREFIX/lib/libcrypto.a;z;resolv;pthread;m;dl"
FLAGS=""
if [[ -n "$SANITIZE" ]]; then
  FLAGS="-fsanitize=$SANITIZE -fno-omit-frame-pointer"
fi

cmake -S "$ROOT/Sources/BaresipKitCore" -B "$BUILD" -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DBARESIP_INCLUDE_DIR="$PREFIX/include/baresip" \
  -DBARESIP_LIBRARY="$PREFIX/lib/libbaresip.a" \
  -DBARESIPKIT_EXTRA_LIBS="$EXTRA" \
  -DBARESIPKIT_BUILD_TESTS=ON \
  -DCMAKE_C_FLAGS="$FLAGS" -DCMAKE_EXE_LINKER_FLAGS="$FLAGS" >/dev/null
cmake --build "$BUILD" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)" >/dev/null

export ASAN_OPTIONS="${ASAN_OPTIONS:-detect_leaks=1}"
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

echo "ALL CORE TESTS PASSED"
