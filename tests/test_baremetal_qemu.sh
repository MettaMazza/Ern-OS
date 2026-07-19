#!/usr/bin/env bash
# Boot the freestanding x86_64 ELF and prove the serial milestone completed.
set -euo pipefail

ERN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERN_KERNEL="$ERN_ROOT/baremetal/build/x86_64/ern-os-x86_64.elf"
ERN_ISO="$ERN_ROOT/baremetal/build/x86_64/ern-os-x86_64.iso"
ERN_ISO_ROOT="$ERN_ROOT/baremetal/build/x86_64/iso-root"
ERN_QEMU="${QEMU_X86_64:-qemu-system-x86_64}"
ERN_LOG="$(mktemp "${TMPDIR:-/tmp}/ern-os-baremetal.XXXXXX")"

cleanup() {
    if [ -n "${ERN_QEMU_PID:-}" ] && kill -0 "$ERN_QEMU_PID" 2>/dev/null; then
        kill "$ERN_QEMU_PID" 2>/dev/null || true
        wait "$ERN_QEMU_PID" 2>/dev/null || true
    fi
    rm -f "$ERN_LOG"
}
trap cleanup EXIT INT TERM

if ! command -v "$ERN_QEMU" >/dev/null 2>&1; then
    echo "Bare-metal test needs qemu-system-x86_64 on PATH." >&2
    exit 1
fi
bash "$ERN_ROOT/build_baremetal.sh"

ERN_BOOT_ARGS=(-kernel "$ERN_KERNEL")
if command -v grub-mkrescue >/dev/null 2>&1; then
    if command -v grub-file >/dev/null 2>&1; then
        grub-file --is-x86-multiboot2 "$ERN_KERNEL"
    fi
    mkdir -p "$ERN_ISO_ROOT/boot/grub"
    cp "$ERN_KERNEL" "$ERN_ISO_ROOT/boot/ern-os-x86_64.elf"
    cp "$ERN_ROOT/baremetal/x86_64/grub.cfg" "$ERN_ISO_ROOT/boot/grub/grub.cfg"
    grub-mkrescue -o "$ERN_ISO" "$ERN_ISO_ROOT" >/dev/null 2>&1
    ERN_BOOT_ARGS=(-boot d -cdrom "$ERN_ISO")
fi

set +e
"$ERN_QEMU" \
    -machine pc \
    -cpu qemu64 \
    -m 64M \
    -display none \
    -serial stdio \
    -monitor none \
    -no-reboot \
    -no-shutdown \
    "${ERN_BOOT_ARGS[@]}" >"$ERN_LOG" 2>&1 &
ERN_QEMU_PID=$!
set -e

ERN_TICKS=0
while [ "$ERN_TICKS" -lt 100 ]; do
    if grep -q "ERN-OS_BAREMETAL_OK" "$ERN_LOG"; then
        break
    fi
    if ! kill -0 "$ERN_QEMU_PID" 2>/dev/null; then
        break
    fi
    sleep 0.1
    ERN_TICKS=$((ERN_TICKS + 1))
done

if ! grep -q "ERN-OS_BAREMETAL_OK" "$ERN_LOG"; then
    echo "BARE-METAL FAIL: QEMU did not emit the success marker in ten seconds." >&2
    sed -n '1,120p' "$ERN_LOG" >&2
    exit 1
fi

if kill -0 "$ERN_QEMU_PID" 2>/dev/null; then
    kill "$ERN_QEMU_PID" 2>/dev/null || true
fi
wait "$ERN_QEMU_PID" 2>/dev/null || true
ERN_QEMU_PID=""

grep -q "Ern-OS bare metal" "$ERN_LOG"
grep -q "CPU mode: long mode (64-bit)" "$ERN_LOG"
grep -q "Ernos payload: the real language crossed the hardware boundary." "$ERN_LOG"

echo "PASS: x86_64 QEMU ran an Ernos-compiled payload in long mode through the serial HAL"
