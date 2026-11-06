#!/usr/bin/env bash
#
# Reproducible build of the BaresipKit C core (libre + baresip + OpenSSL + Opus
# [+ libvpx]) for iOS device arm64 and iOS simulator arm64, packaged as an
# XCFramework consumed by the SPM binaryTarget.
#
# Usage:
#   Build/build-xcframework.sh                # all iOS slices, MODULE_SET=default
#   MODULE_SET=minimal Build/build-xcframework.sh
#   SLICES="ios-arm64" Build/build-xcframework.sh
#   PLATFORM=host Build/build-xcframework.sh  # native build for CI / sanitizers
#
# Environment:
#   MODULE_SET     minimal | default | full            (default: default)
#   SLICES         space separated subset of:
#                  ios-arm64 ios-arm64-simulator ios-x86_64-simulator
#   PLATFORM       ios | host                         (default: ios)
#   DEPS_DIR       where pinned sources are cloned    (default: Build/.deps)
#   OUT_DIR        build output                       (default: Build/out)
#   SANITIZE       address,undefined (host only)
#   JOBS           parallel jobs                      (default: nproc / sysctl)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/Build/versions.env"
source "$ROOT/Build/module-sets.env"

MODULE_SET="${MODULE_SET:-default}"
PLATFORM="${PLATFORM:-ios}"
DEPS_DIR="${DEPS_DIR:-$ROOT/Build/.deps}"
OUT_DIR="${OUT_DIR:-$ROOT/Build/out}"
SANITIZE="${SANITIZE:-}"
if [[ "$PLATFORM" == "ios" ]]; then
  SLICES="${SLICES:-ios-arm64 ios-arm64-simulator}"
else
  SLICES="host"
fi
if [[ -z "${JOBS:-}" ]]; then
  JOBS="$( (nproc 2>/dev/null || sysctl -n hw.ncpu) )"
fi

modules_var="MODULES_${MODULE_SET}"
MODULES="${!modules_var:?unknown MODULE_SET '$MODULE_SET'}"
if [[ "$PLATFORM" == "host" ]]; then
  MODULES="${MODULES//;audiounit/}"
  MODULES="${MODULES//;avcapture/}"
fi

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

fetch() {
  local name="$1" repo="$2" tag="$3" commit="$4"
  local dir="$DEPS_DIR/$name"
  if [[ ! -d "$dir/.git" ]]; then
    log "cloning $name $tag"
    git clone --quiet --depth 1 --branch "$tag" "$repo" "$dir"
  fi
  local head
  head="$(git -C "$dir" rev-parse HEAD)"
  if [[ -n "$commit" && "$head" != "$commit" ]]; then
    die "$name: HEAD $head does not match pinned $commit"
  fi
  printf '%s %s %s\n' "$name" "$tag" "$head" >> "$OUT_DIR/pins.txt"
}

apply_patches() {
  local name="$1"
  local dir="$DEPS_DIR/$name"
  git -C "$dir" checkout --quiet -- .
  for p in "$ROOT"/Patches/*-"$name"-*.patch; do
    [[ -e "$p" ]] || continue
    log "applying $(basename "$p")"
    git -C "$dir" apply --3way "$p"
  done
}

slice_flags() {
  case "$1" in
    ios-arm64)
      SDK=iphoneos; ARCH=arm64; MIN_FLAG="-mios-version-min=$IOS_DEPLOYMENT_TARGET"
      OPENSSL_TARGET=ios64-xcrun ;;
    ios-arm64-simulator)
      SDK=iphonesimulator; ARCH=arm64; MIN_FLAG="-mios-simulator-version-min=$IOS_DEPLOYMENT_TARGET"
      OPENSSL_TARGET=iossimulator-arm64-xcrun ;;
    ios-x86_64-simulator)
      SDK=iphonesimulator; ARCH=x86_64; MIN_FLAG="-mios-simulator-version-min=$IOS_DEPLOYMENT_TARGET"
      OPENSSL_TARGET=iossimulator-x86_64-xcrun ;;
    host)
      SDK=""; ARCH=""; MIN_FLAG=""; OPENSSL_TARGET="" ;;
    *) die "unknown slice $1" ;;
  esac
}

cmake_common() {
  local prefix="$1"; shift
  local args=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix"
              -DCMAKE_PREFIX_PATH="$prefix" -DCMAKE_FIND_ROOT_PATH="$prefix")
  if [[ "$PLATFORM" == "ios" ]]; then
    args+=(-DCMAKE_TOOLCHAIN_FILE="$ROOT/Build/cmake/ios.toolchain.cmake"
           -DBARESIPKIT_SDK="$SDK"
           -DBARESIPKIT_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
           -DCMAKE_OSX_ARCHITECTURES="$ARCH")
  elif [[ -n "$SANITIZE" ]]; then
    args+=(-DCMAKE_C_FLAGS="-fsanitize=$SANITIZE -fno-omit-frame-pointer"
           -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=$SANITIZE")
  fi
  printf '%s\n' "${args[@]}"
}

build_openssl() {
  local slice="$1" prefix="$2"
  local src="$DEPS_DIR/openssl" bdir="$OUT_DIR/$slice/build/openssl"
  [[ -f "$prefix/lib/libssl.a" ]] && return
  log "[$slice] OpenSSL $OPENSSL_TAG"
  rm -rf "$bdir"; mkdir -p "$bdir"
  local target="$OPENSSL_TARGET"
  if [[ "$PLATFORM" == "host" ]]; then
    case "$(uname -s)-$(uname -m)" in
      Linux-x86_64) target=linux-x86_64 ;;
      Linux-aarch64) target=linux-aarch64 ;;
      Darwin-arm64) target=darwin64-arm64-cc ;;
      Darwin-x86_64) target=darwin64-x86_64-cc ;;
      *) die "cannot pick a host OpenSSL target for $(uname -s)-$(uname -m)" ;;
    esac
  fi
  (cd "$bdir" && "$src/Configure" "$target" --prefix="$prefix" --libdir=lib \
      no-shared no-dso no-engine no-module no-apps no-tests no-docs no-legacy \
      no-comp no-ssl3 no-weak-ssl-ciphers no-ui-console \
      no-async $MIN_FLAG >/dev/null)
  make -C "$bdir" -j"$JOBS" build_libs >/dev/null
  make -C "$bdir" install_dev >/dev/null
}

build_opus() {
  local slice="$1" prefix="$2"
  local src="$DEPS_DIR/opus" bdir="$OUT_DIR/$slice/build/opus"
  [[ -f "$prefix/lib/libopus.a" ]] && return
  log "[$slice] Opus $OPUS_TAG"
  mapfile -t common < <(cmake_common "$prefix")
  cmake -S "$src" -B "$bdir" "${common[@]}" -DBUILD_SHARED_LIBS=OFF \
        -DOPUS_BUILD_PROGRAMS=OFF -DOPUS_BUILD_TESTING=OFF >/dev/null
  cmake --build "$bdir" -j"$JOBS" >/dev/null
  cmake --install "$bdir" >/dev/null
}

build_libvpx() {
  local slice="$1" prefix="$2"
  local src="$DEPS_DIR/libvpx" bdir="$OUT_DIR/$slice/build/libvpx"
  [[ -f "$prefix/lib/libvpx.a" ]] && return
  log "[$slice] libvpx $LIBVPX_TAG"
  rm -rf "$bdir"; mkdir -p "$bdir"
  local target
  case "$slice" in
    ios-arm64) target=arm64-darwin20-gcc ;;
    ios-arm64-simulator) target=arm64-iphonesimulator-gcc ;;
    ios-x86_64-simulator) target=x86_64-iphonesimulator-gcc ;;
    host) target="" ;;
  esac
  (cd "$bdir" && "$src/configure" ${target:+--target=$target} --prefix="$prefix" \
      --disable-examples --disable-tools --disable-docs --disable-unit-tests \
      --enable-vp8 --disable-vp9 --enable-pic --disable-shared --enable-static >/dev/null)
  make -C "$bdir" -j"$JOBS" >/dev/null
  make -C "$bdir" install >/dev/null
}

build_libre() {
  local slice="$1" prefix="$2"
  local src="$DEPS_DIR/re" bdir="$OUT_DIR/$slice/build/re"
  log "[$slice] libre $LIBRE_TAG"
  mapfile -t common < <(cmake_common "$prefix")
  cmake -S "$src" -B "$bdir" "${common[@]}" \
        -DLIBRE_BUILD_SHARED=OFF -DLIBRE_BUILD_STATIC=ON \
        -DUSE_OPENSSL=ON -DOPENSSL_ROOT_DIR="$prefix" \
        -DUSE_BFCP=OFF -DUSE_RTMP=OFF -DUSE_PCP=OFF -DUSE_TRACE=OFF >/dev/null
  cmake --build "$bdir" -j"$JOBS" >/dev/null
  cmake --install "$bdir" >/dev/null
}

build_baresip() {
  local slice="$1" prefix="$2"
  local src="$DEPS_DIR/baresip" bdir="$OUT_DIR/$slice/build/baresip"
  log "[$slice] baresip $BARESIP_TAG modules: $MODULES"
  mapfile -t common < <(cmake_common "$prefix")
  cmake -S "$src" -B "$bdir" "${common[@]}" -DSTATIC=ON "-DMODULES=$MODULES" >/dev/null
  cmake --build "$bdir" -j"$JOBS" --target baresip >/dev/null
  cp "$bdir/libbaresip.a" "$prefix/lib/libbaresip.a"
  mkdir -p "$prefix/include/baresip"
  cp "$src/include/baresip.h" "$prefix/include/baresip/"
}

merge_slice() {
  local slice="$1" prefix="$2"
  local out="$OUT_DIR/$slice/lib"
  log "[$slice] merging static archives"
  mkdir -p "$out"
  local libs=("$prefix/lib/libbaresip.a" "$prefix/lib/libre.a" "$prefix/lib/libopus.a"
              "$prefix/lib/libssl.a" "$prefix/lib/libcrypto.a")
  [[ -f "$prefix/lib/libvpx.a" ]] && libs+=("$prefix/lib/libvpx.a")
  if [[ "$PLATFORM" == "ios" ]]; then
    xcrun libtool -static -no_warning_for_no_symbols -o "$out/libBaresipKitCore.a" "${libs[@]}"
  else
    rm -f "$out/libBaresipKitCore.a"
    {
      printf 'CREATE %s\n' "$out/libBaresipKitCore.a"
      for l in "${libs[@]}"; do printf 'ADDLIB %s\n' "$l"; done
      printf 'SAVE\nEND\n'
    } | ar -M
    ranlib "$out/libBaresipKitCore.a"
  fi
  mkdir -p "$OUT_DIR/$slice/Headers"
  cp "$ROOT/Sources/BaresipKitCore/include/baresip_kit.h" "$OUT_DIR/$slice/Headers/"
  cat > "$OUT_DIR/$slice/Headers/module.modulemap" <<MM
module BaresipKitCore {
    umbrella header "baresip_kit.h"
    export *
    link "BaresipKitCore"
    link framework "AudioToolbox"
    link framework "AVFoundation"
    link framework "CoreMedia"
    link framework "CoreVideo"
    link framework "Foundation"
    link framework "Security"
    link framework "VideoToolbox"
    link "resolv"
    link "z"
}
MM
  if [[ "$PLATFORM" == "ios" ]]; then
    printf '%s %s\n' "$slice" "$(stat -f%z "$out/libBaresipKitCore.a")" >> "$OUT_DIR/sizes.txt"
    xcrun size -m "$out/libBaresipKitCore.a" | awk '/^total/{print "'"$slice"' text+data", $2}' >> "$OUT_DIR/sizes.txt" || true
  else
    printf '%s %s\n' "$slice" "$(stat -c%s "$out/libBaresipKitCore.a")" >> "$OUT_DIR/sizes.txt"
  fi
}

create_xcframework() {
  log "creating XCFramework"
  local args=()
  for slice in $SLICES; do
    args+=(-library "$OUT_DIR/$slice/lib/libBaresipKitCore.a" -headers "$OUT_DIR/$slice/Headers")
  done
  rm -rf "$OUT_DIR/BaresipKitCore.xcframework" "$OUT_DIR/BaresipKitCore.xcframework.zip"
  xcodebuild -create-xcframework "${args[@]}" -output "$OUT_DIR/BaresipKitCore.xcframework" >/dev/null
  (cd "$OUT_DIR" && ditto -c -k --keepParent BaresipKitCore.xcframework BaresipKitCore.xcframework.zip)
  (cd "$OUT_DIR" && swift package compute-checksum BaresipKitCore.xcframework.zip > checksum.txt)
  log "checksum: $(cat "$OUT_DIR/checksum.txt")"
}

main() {
  mkdir -p "$DEPS_DIR" "$OUT_DIR"
  : > "$OUT_DIR/pins.txt"
  : > "$OUT_DIR/sizes.txt"

  fetch re "$LIBRE_REPO" "$LIBRE_TAG" "$LIBRE_COMMIT"
  fetch baresip "$BARESIP_REPO" "$BARESIP_TAG" "$BARESIP_COMMIT"
  fetch openssl "$OPENSSL_REPO" "$OPENSSL_TAG" "$OPENSSL_COMMIT"
  fetch opus "$OPUS_REPO" "$OPUS_TAG" "$OPUS_COMMIT"
  if [[ "$MODULES" == *vp8* ]]; then
    fetch libvpx "$LIBVPX_REPO" "$LIBVPX_TAG" "$LIBVPX_COMMIT"
  fi
  apply_patches re
  apply_patches baresip

  for slice in $SLICES; do
    slice_flags "$slice"
    local prefix="$OUT_DIR/$slice/prefix"
    mkdir -p "$prefix"
    build_openssl "$slice" "$prefix"
    build_opus "$slice" "$prefix"
    if [[ "$MODULES" == *vp8* ]]; then build_libvpx "$slice" "$prefix"; fi
    build_libre "$slice" "$prefix"
    build_baresip "$slice" "$prefix"
    merge_slice "$slice" "$prefix"
  done

  if [[ "$PLATFORM" == "ios" ]]; then
    create_xcframework
  fi

  log "done"
  cat "$OUT_DIR/pins.txt"
  cat "$OUT_DIR/sizes.txt"
}

main "$@"
