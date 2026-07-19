# The road to bare metal

Ern-OS today runs as a hosted operating system: the hal drives a macOS or
Linux machine underneath. Phase 2 is booting on real hardware (or QEMU)
with nothing underneath. This page is the honest list of what that takes —
and nothing else, because the layer rule keeps the list from growing.

## Current checkpoint

The first x86_64/QEMU checkpoint is implemented under `baremetal/`:

- a valid Multiboot2 ELF header and GRUB ISO;
- a 32-bit entry that builds page tables and enters 64-bit long mode;
- a private 16 KiB stack and 1 MiB freestanding bump allocator;
- COM1 terminal and CPU halt HAL contracts;
- `epc freestanding`, which runs the normal Ernos frontend and code generator
  but emits a host-free runtime ABI instead of libc/pthreads and a host `main`;
- an Ernos-authored kernel payload linked into the ELF and proven over COM1;
- a deterministic QEMU serial smoke test and dedicated Linux CI job.

The hosted suite also compiles every bootstrap source as a freestanding x86_64
ELF object, so a missing host header or accidental libc call fails early. The
native Mac development host currently lacks `ld.lld`/GRUB, so the linked boot
proof is owned by the Linux QEMU CI job.

## What must change (and what must not)

Everything above the hal — the kernel, the shell, the apps — is already
written against a small contract surface: terminal, disk, clock, machine,
hosted process control and graphical glass. The kernel/userland contracts do
not change. The work is:

### 1. The Ernos runtime must learn to live without a host

The generated C currently needs libc and pthreads. Bare metal needs, in
the language repo:

- **A freestanding allocator.** The garbage collector calls malloc/free;
  it needs a small allocator over a fixed memory range instead.
- **A scheduler instead of pthreads.** `spawn`, channels and `sync` sit
  on pthreads today; a cooperative scheduler (the async event loop is
  already cooperative) is the honest first step — threads can wait.
- **A freestanding compile target.** `epc freestanding program.ep`
  emitting C with no libc includes, compiled with
  `clang -ffreestanding -nostdlib` for `x86_64-elf` or `aarch64`, plus a
  small linker script and boot stub (the one unavoidable piece of
  assembly, ~100 lines: set up the stack, jump to main).

### 2. The six HAL modules get hardware/freestanding editions

| file | hosted today | bare metal edition |
|---|---|---|
| `the_terminal.ep` | display / read_line | serial port (UART) first, VGA text later |
| `the_disk.ep` | host files under `disk/` | a block device and a tiny file layout |
| `the_clock.ep` | host clock | the timer interrupt, a tick counter |
| `the_machine.ep` | os_name / exit | CPU idle loop, reboot port |
| `outside_programs.ep` | host processes and binary swaps | disabled, or an on-device updater much later |
| `the_glass.ep` | dynamic raylib window | framebuffer, pointer and keyboard drivers |

The disk edition is the real work: a simple content layout (a table of
names → block runs) behind the same eight verbs. Everything above it —
homes, permissions, notes, the log — runs unchanged.

### 3. Boot

GRUB/multiboot (x86_64) or a flat image for QEMU's `-kernel` (aarch64).
First milestone: Ern-OS banner over the serial port in QEMU; then the
keyboard; then the disk; then login — the same login, byte for byte.

## Order of attack, when the day comes

1. ~~Freestanding boot, allocator, serial terminal and machine halt in QEMU.~~
2. ~~Add `epc freestanding` so a small Ernos program targets the new runtime
   contracts and prints through the same serial HAL.~~
3. Replace pthread-backed `spawn`/channels with a cooperative scheduler; add a
   timer-backed `the_clock` edition.
4. Add a RAM-disk edition of `the_disk`, then boot the untouched kernel and
   shell on top. Login over serial.
5. Add keyboard input, block-device persistence, then a framebuffer edition
   of `the_glass` for the visual desktop.

Until then, every line written above the hal is already bare-metal code —
it just doesn't know it yet.
