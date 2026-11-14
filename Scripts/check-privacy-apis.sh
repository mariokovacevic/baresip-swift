#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
manifest="$root/Sources/BaresipKit/Resources/PrivacyInfo.xcprivacy"
framework="$root/Build/out/BaresipKitCore.xcframework"

[[ -d "$framework" ]] || {
  echo "Build/out/BaresipKitCore.xcframework is missing; run Build/build-xcframework.sh first" >&2
  exit 1
}

category() {
  case "$1" in
    _stat | _fstat | _lstat | _fstatat | _stat64 | _fstat64 | _lstat64 | _stat\$INODE64 | _fstat\$INODE64 | _lstat\$INODE64 \
      | _fstatat\$INODE64 | _getattrlist | _fgetattrlist | _getattrlistat | _getattrlistbulk)
      echo FileTimestamp ;;
    _statfs | _fstatfs | _statvfs | _fstatvfs | _statfs64 | _fstatfs64 | _statfs\$INODE64 | _fstatfs\$INODE64)
      echo DiskSpace ;;
    _mach_absolute_time)
      echo SystemBootTime ;;
  esac
}

status=0
found=""
while IFS= read -r library; do
  slice=${library#"$framework"/}
  while IFS= read -r symbol; do
    name=$(category "$symbol")
    [[ -n "$name" ]] || continue
    found+="$name $slice $symbol"$'\n'
  done < <(nm -u "$library" 2>/dev/null | awk 'NF == 1 { print $1 }' | sort -u)
done < <(find "$framework" -name '*.a')

if [[ -z "$found" ]]; then
  echo "The XCFramework uses no required-reason API"
  exit 0
fi

echo "Required-reason APIs used by the XCFramework:"
sed '/^$/d' <<<"$found" | sort -u | sed 's/^/  /'
for name in $(sed '/^$/d' <<<"$found" | cut -d' ' -f1 | sort -u); do
  if ! grep -q "<string>NSPrivacyAccessedAPICategory$name</string>" "$manifest"; then
    echo "error: Sources/BaresipKit/Resources/PrivacyInfo.xcprivacy does not declare NSPrivacyAccessedAPICategory$name" >&2
    status=1
  fi
done
exit "$status"
