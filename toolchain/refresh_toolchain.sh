#!/usr/bin/env bash
# refresh_toolchain.sh — re-copy the vendored toolchain pieces from the
# Ernos language repo. Run this only when the language itself has moved
# forward and Ern-OS should pick up the new compiler and stdlib.
#
# Ern-OS never edits stdlib/ or epc_bootstrap.c directly — they are copies,
# owned by the language repo.
#
# Usage:  bash toolchain/refresh_toolchain.sh [path-to-language-repo]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LANG_REPO="${1:-$HOME/Desktop/ErnosPlain Programing Language}"
if [ ! -f "$LANG_REPO/bootstrap/epc_bootstrap.c" ]; then
    echo "error: language repo not found at: $LANG_REPO" >&2
    exit 1
fi
echo "[refresh] copying stdlib/ and epc_bootstrap.c from: $LANG_REPO"
rm -rf "$ROOT/stdlib"
cp -R "$LANG_REPO/stdlib" "$ROOT/stdlib"
cp "$LANG_REPO/bootstrap/epc_bootstrap.c" "$ROOT/toolchain/epc_bootstrap.c"
rm -f "$ROOT/toolchain/epc"
echo "[refresh] done — rebuild with: bash toolchain/build_toolchain.sh"
