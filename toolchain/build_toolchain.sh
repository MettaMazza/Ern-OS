#!/usr/bin/env bash
# build_toolchain.sh — build the Ernos compiler from the frozen C bootstrap.
#
# This is the whole trick that makes Ern-OS self-contained: the only thing
# this machine needs is a C compiler. No Rust, no cargo, no internet.
#
#   toolchain/epc_bootstrap.c  is the Ernos compiler, compiled by itself.
#   Compiling it with clang yields toolchain/epc, which can then compile
#   any .ep program — including Ern-OS.
#
# Usage:  bash toolchain/build_toolchain.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
CC="${CC:-clang}"
echo "[toolchain] compiling the Ernos compiler from frozen C with $CC ..."
"$CC" -O2 toolchain/epc_bootstrap.c -o toolchain/epc -lpthread
echo "[toolchain] done — toolchain/epc is ready."
