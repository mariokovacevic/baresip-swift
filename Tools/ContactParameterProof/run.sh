#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${LIBRE_PREFIX:?set LIBRE_PREFIX to a libre install prefix}"
BUILD="${BUILD_DIR:-$HERE/build}"
TRACE="${TRACE_FILE:-$HERE/trace.txt}"

cmake -S "$HERE" -B "$BUILD" -DCMAKE_PREFIX_PATH="$PREFIX" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$BUILD" --target contact_proof >/dev/null

python3 "$HERE/fake_registrar.py" "$TRACE" &
REG_PID=$!
sleep 0.5

"$BUILD/contact_proof"
wait "$REG_PID"

python3 "$HERE/verify_trace.py" "$TRACE"
