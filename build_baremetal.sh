#!/usr/bin/env bash
# Build the first x86_64 bare-metal Ern-OS milestone.
set -euo pipefail

ERN_ROOT="$(cd "$(dirname "$0")" && pwd)"
ERN_BUILD="$ERN_ROOT/baremetal/build/x86_64"
ERN_CC="${CC:-clang}"
ERN_LD="${LD_LLD:-ld.lld}"
ERN_OBJECTS_ONLY=0
if [ "${1:-}" = "--objects-only" ]; then
    ERN_OBJECTS_ONLY=1
elif [ -n "${1:-}" ]; then
    echo "Usage: bash build_baremetal.sh [--objects-only]" >&2
    exit 2
fi

if ! command -v "$ERN_CC" >/dev/null 2>&1; then
    echo "Bare-metal build needs clang on PATH." >&2
    exit 1
fi
mkdir -p "$ERN_BUILD"

if [ ! -x "$ERN_ROOT/toolchain/epc" ]; then
    echo "[bare-metal] building the frozen self-hosted compiler ..."
    CC="$ERN_CC" bash "$ERN_ROOT/toolchain/build_toolchain.sh"
fi

echo "[bare-metal] compiling the Ernos kernel payload through the real frontend ..."
(
    cd "$ERN_BUILD"
    "$ERN_ROOT/toolchain/epc" freestanding "$ERN_ROOT/baremetal/kernel/hello.ep"
)
ERN_PAYLOAD="$ERN_BUILD/hello_freestanding.c"
if grep -Eiq '#include <(stdio|stdlib|string|pthread|unistd|windows)\.h>|(fopen|system|pthread_create|CreateThread|int main)[[:space:]]*\(' "$ERN_PAYLOAD"; then
    echo "Freestanding compiler emitted a hosted dependency." >&2
    exit 1
fi

ERN_CFLAGS=(
    --target=x86_64-unknown-none-elf
    -std=c11
    -ffreestanding
    -fno-builtin
    -fno-pic
    -fno-pie
    -fno-stack-protector
    -mno-red-zone
    -mcmodel=small
    -Wall
    -Wextra
    -Werror
    -I "$ERN_ROOT/baremetal/include"
)

echo "[bare-metal] compiling the x86_64 bootstrap and freestanding runtime ..."
"$ERN_CC" "${ERN_CFLAGS[@]}" -c "$ERN_ROOT/baremetal/x86_64/boot.S" -o "$ERN_BUILD/boot.o"
"$ERN_CC" "${ERN_CFLAGS[@]}" -c "$ERN_ROOT/baremetal/runtime/freestanding.c" -o "$ERN_BUILD/freestanding.o"
"$ERN_CC" "${ERN_CFLAGS[@]}" -c "$ERN_ROOT/baremetal/hal/x86_64/terminal.c" -o "$ERN_BUILD/terminal.o"
"$ERN_CC" "${ERN_CFLAGS[@]}" -c "$ERN_ROOT/baremetal/hal/x86_64/machine.c" -o "$ERN_BUILD/machine.o"
"$ERN_CC" "${ERN_CFLAGS[@]}" -c "$ERN_ROOT/baremetal/kernel/main.c" -o "$ERN_BUILD/main.o"
"$ERN_CC" "${ERN_CFLAGS[@]}" -c "$ERN_PAYLOAD" -o "$ERN_BUILD/hello_ernos.o"

if [ "$ERN_OBJECTS_ONLY" -eq 1 ]; then
    echo "[bare-metal] object validation complete (--objects-only)"
    exit 0
fi
if ! command -v "$ERN_LD" >/dev/null 2>&1; then
    echo "Bare-metal objects compiled, but final ELF linking needs ld.lld on PATH (install LLVM/lld)." >&2
    exit 1
fi

echo "[bare-metal] linking the Multiboot2 ELF ..."
"$ERN_LD" -m elf_x86_64 -nostdlib \
    -T "$ERN_ROOT/baremetal/x86_64/linker.ld" \
    -o "$ERN_BUILD/ern-os-x86_64.elf" \
    "$ERN_BUILD/boot.o" \
    "$ERN_BUILD/freestanding.o" \
    "$ERN_BUILD/terminal.o" \
    "$ERN_BUILD/machine.o" \
    "$ERN_BUILD/main.o" \
    "$ERN_BUILD/hello_ernos.o"

echo "[bare-metal] ready: baremetal/build/x86_64/ern-os-x86_64.elf"
