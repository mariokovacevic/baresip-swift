#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${LIBRE_PREFIX:?set LIBRE_PREFIX to a libre install prefix}"
BARESIP_SRC="${BARESIP_SRC:?set BARESIP_SRC to a patched baresip checkout}"
BARESIP_BUILD="${BARESIP_BUILD:?set BARESIP_BUILD to a STATIC=ON baresip build dir}"
OUT="${BUILD_DIR:-$HERE/build}"
TRACE="${TRACE_FILE:-$HERE/trace-baresip.txt}"
HOSTIP="${REGISTRAR_HOST:-$(hostname -I | awk '{print $1}')}"
EXTRA_LIBS="${EXTRA_LIBS:--lssl -lcrypto -lz -lresolv -lpthread -lm -ldl}"

mkdir -p "$OUT"
cc -DHAVE_UNIXSOCK=0 -DREGISTRAR_HOST="\"$HOSTIP\"" \
   -I "$BARESIP_SRC/include" -I "$PREFIX/include/re" \
   "$HERE/contact_proof_baresip.c" -o "$OUT/contact_proof_baresip" \
   "$BARESIP_BUILD/libbaresip.a" "$PREFIX/lib/libre.a" \
   $( [ -f "$PREFIX/lib/libopus.a" ] && echo "$PREFIX/lib/libopus.a" ) \
   $EXTRA_LIBS

REGISTRAR_HOST="$HOSTIP" python3 "$HERE/fake_registrar.py" "$TRACE" &
REG_PID=$!
sleep 0.5

"$OUT/contact_proof_baresip"
wait "$REG_PID"

python3 "$HERE/verify_trace.py" "$TRACE" "A,A,B,B,B0"
