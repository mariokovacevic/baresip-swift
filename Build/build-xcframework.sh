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
#   PLATFORM=android Build/build-xcframework.sh  # arm64-v8a and x86_64 for the AAR
#
# Environment:
#   MODULE_SET     minimal | default | full            (default: default)
#   SLICES         space separated subset of:
#                  ios-arm64 ios-arm64-simulator ios-x86_64-simulator macos-arm64
#                  android-arm64-v8a android-x86_64
#   PLATFORM       ios | host | android               (default: ios)
#   ANDROID_NDK_HOME  the NDK of ANDROID_NDK_VERSION   (android only)
#   DEPS_DIR       where pinned sources are cloned    (default: Build/.deps)
#   OUT_DIR        build output                       (default: Build/out)
#   SANITIZE       address,undefined or thread (host only; thread uses
#                  pthreads instead of C11 threads, which TSan does not see)
#   JOBS           parallel jobs                      (default: nproc / sysctl)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/Build/versions.env"
source "$ROOT/Build/module-sets.env"

SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || echo 315532800)}"
export SOURCE_DATE_EPOCH
export ZERO_AR_DATE=1
PREFIX_MAP="-ffile-prefix-map=$ROOT=."

MODULE_SET="${MODULE_SET:-default}"
PLATFORM="${PLATFORM:-ios}"
DEPS_DIR="${DEPS_DIR:-$ROOT/Build/.deps}"
OUT_DIR="${OUT_DIR:-$ROOT/Build/out}"
SANITIZE="${SANITIZE:-}"
OPENSSL_CONFIG_DIR=/etc/ssl
OPENSSL_PLUGIN_DIR=/usr/lib/ossl-modules
if [[ "$PLATFORM" == "ios" ]]; then
  SLICES="${SLICES:-ios-arm64 ios-arm64-simulator macos-arm64}"
elif [[ "$PLATFORM" == "android" ]]; then
  SLICES="${SLICES:-android-arm64-v8a android-x86_64}"
else
  SLICES="host"
fi
if [[ -z "${JOBS:-}" ]]; then
  JOBS="$( (nproc 2>/dev/null || sysctl -n hw.ncpu) )"
fi

modules_var="MODULES_${MODULE_SET}"
MODULES="${!modules_var:?unknown MODULE_SET '$MODULE_SET'}"
if [[ "$PLATFORM" == "host" || "$PLATFORM" == "android" ]]; then
  MODULES="${MODULES//;audiounit/}"
  MODULES="${MODULES//;avcapture/}"
fi
if [[ "$PLATFORM" == "android" ]]; then
  MODULES="${MODULES};aaudio"
  : "${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME to NDK $ANDROID_NDK_VERSION}"
  NDK_BIN="$(echo "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/*/bin)"
fi

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

checked_out_commit() {
  [[ -d "$1/.git" ]] && git -C "$1" rev-parse HEAD 2>/dev/null || true
}

fetch() {
  local name="$1" repo="$2" tag="$3" commit="$4"
  local dir="$DEPS_DIR/$name"
  [[ -n "$commit" ]] || die "$name: no pinned commit in Build/versions.env"
  if [[ "$(checked_out_commit "$dir")" != "$commit" ]]; then
    log "cloning $name $tag"
    rm -rf "$dir"
    git clone --quiet --depth 1 --branch "$tag" "$repo" "$dir"
  fi
  local head
  head="$(checked_out_commit "$dir")"
  if [[ "$head" != "$commit" ]]; then
    die "$name: $tag is at ${head:-no commit}, pinned is $commit"
  fi
  printf '%s %s %s\n' "$name" "$tag" "$head" >> "$OUT_DIR/pins.txt"
}

apply_patches() {
  local name="$1"
  local dir="$DEPS_DIR/$name"
  git -C "$dir" reset --quiet --hard HEAD
  git -C "$dir" clean --quiet -fdx
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
    macos-arm64)
      SDK=macosx; ARCH=arm64; MIN_FLAG="-mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
      OPENSSL_TARGET=darwin64-arm64-cc ;;
    host)
      SDK=""; ARCH=""; MIN_FLAG=""; OPENSSL_TARGET="" ;;
    android-arm64-v8a)
      SDK=android; ARCH=arm64-v8a; MIN_FLAG="-D__ANDROID_API__=$ANDROID_MIN_SDK"
      OPENSSL_TARGET=android-arm64; ANDROID_TRIPLE=aarch64-linux-android ;;
    android-x86_64)
      SDK=android; ARCH=x86_64; MIN_FLAG="-D__ANDROID_API__=$ANDROID_MIN_SDK"
      OPENSSL_TARGET=android-x86_64; ANDROID_TRIPLE=x86_64-linux-android ;;
    *) die "unknown slice $1" ;;
  esac
}

cmake_common() {
  local prefix="$1"; shift
  local args=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix"
              -DCMAKE_PREFIX_PATH="$prefix" -DCMAKE_FIND_ROOT_PATH="$prefix"
              -DCMAKE_POSITION_INDEPENDENT_CODE=ON
              -DCMAKE_PROJECT_INCLUDE="$ROOT/Build/cmake/reproducible.cmake"
              -DBARESIPKIT_PREFIX_MAP="$PREFIX_MAP")
  if [[ "$SDK" == "macosx" ]]; then
    args+=(-DCMAKE_OSX_SYSROOT=macosx
           -DCMAKE_OSX_ARCHITECTURES="$ARCH"
           -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET")
  elif [[ "$SDK" == "android" ]]; then
    args+=(-DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"
           -DANDROID_ABI="$ARCH" -DANDROID_PLATFORM="android-$ANDROID_MIN_SDK"
           -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH
           -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH)
  elif [[ "$PLATFORM" == "ios" ]]; then
    args+=(-DCMAKE_TOOLCHAIN_FILE="$ROOT/Build/cmake/ios.toolchain.cmake"
           -DBARESIPKIT_SDK="$SDK"
           -DBARESIPKIT_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
           -DCMAKE_OSX_ARCHITECTURES="$ARCH")
  elif [[ -n "$SANITIZE" ]]; then
    args+=(-DCMAKE_C_FLAGS="-fsanitize=$SANITIZE -fno-omit-frame-pointer"
           -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=$SANITIZE")
    if [[ ",$SANITIZE," == *,thread,* ]]; then
      args+=(-DHAVE_THREADS_FUN=OFF -DBSK_HAVE_THREADS_FUN=OFF)
    fi
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
  local ndk_env=()
  if [[ "$SDK" == "android" ]]; then
    ndk_env=(env ANDROID_NDK_ROOT="$ANDROID_NDK_HOME" PATH="$NDK_BIN:$PATH")
  fi
  (cd "$bdir" && ${ndk_env[@]+"${ndk_env[@]}"} "$src/Configure" "$target" --prefix="$prefix" --libdir=lib \
      --openssldir="$OPENSSL_CONFIG_DIR" \
      no-shared no-dso no-engine no-module no-apps no-tests no-docs no-legacy \
      no-comp no-ssl3 no-weak-ssl-ciphers no-ui-console no-autoload-config \
      no-async no-quic $MIN_FLAG "$PREFIX_MAP" >/dev/null)
  local plugin_dirs=(ENGINESDIR="$OPENSSL_PLUGIN_DIR" MODULESDIR="$OPENSSL_PLUGIN_DIR")
  ${ndk_env[@]+"${ndk_env[@]}"} make -C "$bdir" -j"$JOBS" "${plugin_dirs[@]}" build_libs >/dev/null
  ${ndk_env[@]+"${ndk_env[@]}"} make -C "$bdir" "${plugin_dirs[@]}" install_dev >/dev/null
}

build_opus() {
  local slice="$1" prefix="$2"
  local src="$DEPS_DIR/opus" bdir="$OUT_DIR/$slice/build/opus"
  [[ -f "$prefix/lib/libopus.a" ]] && return
  log "[$slice] Opus $OPUS_TAG"
  local common=() l
  while IFS= read -r l; do common+=("$l"); done < <(cmake_common "$prefix")
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
    macos-arm64) target=arm64-darwin20-gcc ;;
    ios-arm64-simulator) target=arm64-iphonesimulator-gcc ;;
    ios-x86_64-simulator) target=x86_64-iphonesimulator-gcc ;;
    android-arm64-v8a) target=arm64-android-gcc ;;
    android-x86_64) target=x86_64-android-gcc ;;
    host) target="" ;;
  esac
  local tools=() as
  if [[ "$SDK" == "android" ]]; then
    as="$NDK_BIN/$ANDROID_TRIPLE$ANDROID_MIN_SDK-clang"
    [[ "$ARCH" == "x86_64" ]] && as=nasm
    tools=(env CC="$NDK_BIN/$ANDROID_TRIPLE$ANDROID_MIN_SDK-clang"
           CXX="$NDK_BIN/$ANDROID_TRIPLE$ANDROID_MIN_SDK-clang++"
           AR="$NDK_BIN/llvm-ar" AS="$as"
           LD="$NDK_BIN/$ANDROID_TRIPLE$ANDROID_MIN_SDK-clang" STRIP="$NDK_BIN/llvm-strip"
           NM="$NDK_BIN/llvm-nm" RANLIB="$NDK_BIN/llvm-ranlib")
  fi
  (cd "$bdir" && ${tools[@]+"${tools[@]}"} "$src/configure" ${target:+--target=$target} --prefix="$prefix" \
      --disable-examples --disable-tools --disable-docs --disable-unit-tests \
      --enable-vp8 --disable-vp9 --enable-pic --disable-shared --enable-static \
      --extra-cflags="$PREFIX_MAP" >/dev/null)
  ${tools[@]+"${tools[@]}"} make -C "$bdir" -j"$JOBS" >/dev/null
  ${tools[@]+"${tools[@]}"} make -C "$bdir" install >/dev/null
}

build_libre() {
  local slice="$1" prefix="$2"
  local src="$DEPS_DIR/re" bdir="$OUT_DIR/$slice/build/re"
  log "[$slice] libre $LIBRE_TAG"
  local common=() l
  while IFS= read -r l; do common+=("$l"); done < <(cmake_common "$prefix")
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
  local common=() l
  while IFS= read -r l; do common+=("$l"); done < <(cmake_common "$prefix")
  cmake -S "$src" -B "$bdir" "${common[@]}" -DSTATIC=ON "-DMODULES=$MODULES" >/dev/null
  cmake --build "$bdir" -j"$JOBS" --target baresip >/dev/null
  cp "$bdir/libbaresip.a" "$prefix/lib/libbaresip.a"
  mkdir -p "$prefix/include/baresip"
  cp "$src/include/baresip.h" "$prefix/include/baresip/"
}

build_facade() {
  local slice="$1" prefix="$2"
  local src="$ROOT/Core" bdir="$OUT_DIR/$slice/build/facade"
  log "[$slice] BaresipKitCore facade"
  local common=() l
  while IFS= read -r l; do common+=("$l"); done < <(cmake_common "$prefix")
  cmake -S "$src" -B "$bdir" "${common[@]}" \
        -DBARESIP_INCLUDE_DIR="$prefix/include/baresip" \
        -DBARESIP_LIBRARY="$prefix/lib/libbaresip.a" >/dev/null
  cmake --build "$bdir" -j"$JOBS" >/dev/null
  cp "$bdir/libbaresipkitcore.a" "$prefix/lib/libbaresipkitcore.a"
}

merge_slice() {
  local slice="$1" prefix="$2"
  local out="$OUT_DIR/$slice/lib"
  log "[$slice] merging static archives"
  mkdir -p "$out"
  local libs=("$prefix/lib/libbaresipkitcore.a" "$prefix/lib/libbaresip.a"
              "$prefix/lib/libre.a" "$prefix/lib/libopus.a"
              "$prefix/lib/libssl.a" "$prefix/lib/libcrypto.a")
  [[ -f "$prefix/lib/libvpx.a" ]] && libs+=("$prefix/lib/libvpx.a")
  local ar=ar ranlib=ranlib
  if [[ "$SDK" == "android" ]]; then
    ar="$NDK_BIN/llvm-ar"; ranlib="$NDK_BIN/llvm-ranlib"
  fi
  if [[ "$PLATFORM" == "ios" || ( "$PLATFORM" == "host" && "$(uname -s)" == Darwin ) ]]; then
    xcrun libtool -static -no_warning_for_no_symbols -o "$out/libBaresipKitCore.a" "${libs[@]}"
  else
    rm -f "$out/libBaresipKitCore.a"
    {
      printf 'CREATE %s\n' "$out/libBaresipKitCore.a"
      for l in "${libs[@]}"; do printf 'ADDLIB %s\n' "$l"; done
      printf 'SAVE\nEND\n'
    } | "$ar" -M
    "$ranlib" "$out/libBaresipKitCore.a"
  fi
  mkdir -p "$OUT_DIR/$slice/Headers"
  cp "$ROOT/Core/include/baresip_kit.h" "$OUT_DIR/$slice/Headers/"
  [[ "$SDK" == "android" ]] || cat > "$OUT_DIR/$slice/Headers/module.modulemap" <<MM
module BaresipKitCore {
    umbrella header "baresip_kit.h"
    export *
    link "BaresipKitCore"
    link framework "AudioToolbox"
    link framework "AVFoundation"
    link framework "CoreAudio"
    link framework "CoreFoundation"
    link framework "CoreMedia"
    link framework "CoreVideo"
    link framework "Foundation"
    link framework "Security"
    link framework "SystemConfiguration"
    link framework "VideoToolbox"
    link "resolv"
    link "z"
}
MM
  if [[ "$PLATFORM" == "ios" ]]; then
    local a
    for a in "$out/libBaresipKitCore.a" "${libs[@]}"; do
      printf '%s %s %s bytes=%s text+data=%s\n' "$MODULE_SET" "$slice" "$(basename "$a")" \
        "$(stat -f%z "$a")" "$(text_data "$a")" >> "$OUT_DIR/sizes.txt"
    done
  elif [[ "$PLATFORM" == "host" && "$(uname -s)" == Darwin ]]; then
    printf '%s %s %s bytes=%s\n' "$MODULE_SET" "$slice" libBaresipKitCore.a \
      "$(stat -f%z "$out/libBaresipKitCore.a")" >> "$OUT_DIR/sizes.txt"
  else
    printf '%s %s %s bytes=%s\n' "$MODULE_SET" "$slice" libBaresipKitCore.a \
      "$(stat -c%s "$out/libBaresipKitCore.a")" >> "$OUT_DIR/sizes.txt"
  fi
}

text_data() {
  xcrun size -m "$1" | awk '
    /Section \((__TEXT|__DATA), / && !/__bss\)|__common\)/ { sub(/.*: /, ""); t += $1 }
    END { print t + 0 }'
}

create_xcframework() {
  log "creating XCFramework"
  local args=()
  for slice in $SLICES; do
    args+=(-library "$OUT_DIR/$slice/lib/libBaresipKitCore.a" -headers "$OUT_DIR/$slice/Headers")
  done
  rm -rf "$OUT_DIR/BaresipKitCore.xcframework" "$OUT_DIR/BaresipKitCore.xcframework.zip"
  xcodebuild -create-xcframework "${args[@]}" -output "$OUT_DIR/BaresipKitCore.xcframework" >/dev/null
  local stamp
  stamp="$(TZ=UTC date -r "$SOURCE_DATE_EPOCH" +%Y%m%d%H%M.%S)"
  find "$OUT_DIR/BaresipKitCore.xcframework" -exec env TZ=UTC touch -h -t "$stamp" {} +
  (cd "$OUT_DIR" && ditto -c -k --norsrc --noextattr --noqtn --keepParent BaresipKitCore.xcframework \
    BaresipKitCore.xcframework.zip)
  (cd "$OUT_DIR" && swift package compute-checksum BaresipKitCore.xcframework.zip > checksum.txt)
  printf '%s xcframework.zip bytes=%s checksum=%s\n' "$MODULE_SET" \
    "$(stat -f%z "$OUT_DIR/BaresipKitCore.xcframework.zip")" "$(cat "$OUT_DIR/checksum.txt")" >> "$OUT_DIR/sizes.txt"
  log "checksum: $(cat "$OUT_DIR/checksum.txt")"
}

main() {
  mkdir -p "$DEPS_DIR" "$OUT_DIR"
  : > "$OUT_DIR/pins.txt"
  touch "$OUT_DIR/sizes.txt"
  grep -v "^$MODULE_SET " "$OUT_DIR/sizes.txt" > "$OUT_DIR/sizes.txt.tmp" || true
  mv "$OUT_DIR/sizes.txt.tmp" "$OUT_DIR/sizes.txt"

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
    build_facade "$slice" "$prefix"
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
