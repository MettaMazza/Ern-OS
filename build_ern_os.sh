#!/usr/bin/env bash
# build_ern_os.sh — build Ern-OS from source, using only clang.
#
#   1. If the vendored Ernos compiler is missing, build it from frozen C.
#   2. Compile start_ern_os.ep (the whole OS) into ./start_ern_os.
#
# The compiler resolves bare imports like `import "fs"` against ./stdlib,
# relative to the current directory — so this script always runs from the
# repo root. Always build with this script.
#
# Usage:  bash build_ern_os.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
if [ ! -x toolchain/epc ]; then
    bash toolchain/build_toolchain.sh
fi
echo "[ern-os] compiling the operating system ..."
./toolchain/epc start_ern_os.ep
echo "[ern-os] done — boot it with: ./start_ern_os"
