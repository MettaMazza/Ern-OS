#!/usr/bin/env bash
# install.sh — from a fresh copy of Ern-OS to a bootable system, with one
# command. The only thing this machine needs is a C compiler (clang).
#
#   bash install.sh           build everything
#   bash install.sh --check   build everything, then run the full test suite
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! command -v clang >/dev/null 2>&1; then
    echo "Ern-OS needs clang. On macOS: xcode-select --install. On Linux: your package manager."
    exit 1
fi

bash toolchain/build_toolchain.sh
bash build_ern_os.sh

if [ "${1:-}" = "--check" ]; then
    bash tests/run_all_tests.sh
fi

echo ""
echo "Ern-OS is ready. Boot it with:"
echo ""
echo "    ./start_ern_os            (the graphical desktop; needs raylib)"
echo "    ./start_ern_os --terminal (a full-screen text desktop, no libraries)"
echo "    ./start_ern_os --plain    (the sentence-only shell)"
echo ""
echo "For the graphical desktop: brew install raylib  (falls back to text without it)."
echo "The first boot prepares the disk and makes you the administrator."
