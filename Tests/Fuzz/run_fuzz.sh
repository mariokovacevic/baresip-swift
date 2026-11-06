#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PREFIX="${PREFIX:?set PREFIX to a host build prefix}"
PREFIX="$(cd "$PREFIX" && pwd)"
OUT="${BUILD_DIR:-$ROOT/Build/out/host/fuzz}"
RUNS="${RUNS:-200000}"
CC="${CC:-clang}"

MODE="${FUZZ_MODE:-libfuzzer}"
SRCS=("$HERE/fuzz_parsers.c" "$ROOT/Core/src/bsk_account.c" "$ROOT/Core/src/bsk_log.c"
      "$ROOT/Core/src/bsk_call.c" "$ROOT/Core/src/bsk_engine.c" "$ROOT/Core/src/bsk_video.c" "$ROOT/Core/src/bsk_tls.c" "$ROOT/Core/src/bsk_rate.c" "$ROOT/Core/src/bsk_message.c")
LIBS=("$PREFIX/lib/libbaresip.a" "$PREFIX/lib/libre.a")
[ -f "$PREFIX/lib/libvpx.a" ] && LIBS+=("$PREFIX/lib/libvpx.a")
LIBS+=("$PREFIX/lib/libopus.a" "$PREFIX/lib/libssl.a" "$PREFIX/lib/libcrypto.a" -lz -lresolv -lpthread -lm -ldl)
INCS=(-I "$ROOT/Core/include" -I "$ROOT/Core/src" -I "$PREFIX/include/re" -I "$PREFIX/include/baresip" -I "$PREFIX/include")
DEFS=(-DDEBUG_MODULE='"bsk"' -DDEBUG_LEVEL=5)

mkdir -p "$OUT/corpus"
printf 'app-id=com.example\npn-tok=abc:remote&def:voip\n' > "$OUT/corpus/contact"
printf 'Authorization: Digest response="deadbeef", pn-tok=0123456789abcdef' > "$OUT/corpus/redact"
printf 'ice,connected,sdpm=0x1234 ltype=host rtype=relay laddr=192.0.2.1:5000 raddr=192.0.2.2:6000' > "$OUT/corpus/ice"

if [[ "$MODE" == "driver" ]]; then
  "${CC:-cc}" -g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer -std=c11 "${INCS[@]}" "${DEFS[@]}" \
    "$HERE/fuzz_driver.c" "${SRCS[@]}" -o "$OUT/fuzz_driver" "${LIBS[@]}"
  "$OUT/fuzz_driver" "$OUT/corpus" "$RUNS"
  echo "fuzz: PASS (driver, $RUNS runs)"
  exit 0
fi

"$CC" -g -O1 -fsanitize=fuzzer,address,undefined -std=c11 \
  "${INCS[@]}" "${DEFS[@]}" \
  "${SRCS[@]}" -o "$OUT/fuzz_parsers" "${LIBS[@]}"

"$OUT/fuzz_parsers" -runs="$RUNS" -max_len=512 "$OUT/corpus"
echo "fuzz: PASS ($RUNS runs)"
