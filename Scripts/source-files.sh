#!/usr/bin/env bash
set -euo pipefail

c_sources() {
  git ls-files 'Core/*.c' 'Core/*.h' 'Core/*.m' \
    'Sources/BaresipKitBridge/*.c' 'Sources/BaresipKitBridge/*.h' \
    'Tests/Core/*.c' 'Tests/Core/*.h' 'Tests/Fuzz/*.c' 'Tools/*.c' \
    ':!Core/third_party'
}

swift_sources() {
  git ls-files '*.swift'
}
