# The road to bare metal

Ern-OS today runs as a hosted operating system: the hal drives a macOS or
Linux machine underneath. Phase 2 is booting on real hardware (or QEMU)
with nothing underneath. This page is the honest list of what that takes —
and nothing else, because the layer rule keeps the list from growing.

## What must change (and what must not)

Everything above the hal — the kernel, the shell, the apps — is already
written against four small contracts (`say`/`ask`, `disk_read`/`disk_write`,
`clock_stamp`, `machine_power_off`). None of it changes. The work is:

### 1. The Ernos runtime must learn to live without a host

The generated C currently needs libc and pthreads. Bare metal needs, in
the language repo:

- **A freestanding allocator.** The garbage collector calls malloc/free;
  it needs a small allocator over a fixed memory range instead.
- **A scheduler instead of pthreads.** `spawn`, channels and `sync` sit
  on pthreads today; a cooperative scheduler (the async event loop is
  already cooperative) is the honest first step — threads can wait.
- **A freestanding compile target.** `epc program.ep --freestanding`
  emitting C with no libc includes, compiled with
  `clang -ffreestanding -nostdlib` for `x86_64-elf` or `aarch64`, plus a
  small linker script and boot stub (the one unavoidable piece of
  assembly, ~100 lines: set up the stack, jump to main).

### 2. The four hal files get hardware editions

| file | hosted today | bare metal edition |
|---|---|---|
| `the_terminal.ep` | display / read_line | serial port (UART) first, VGA text later |
| `the_disk.ep` | host files under `disk/` | a block device and a tiny file layout |
| `the_clock.ep` | host clock | the timer interrupt, a tick counter |
| `the_machine.ep` | os_name / exit | CPU idle loop, reboot port |

The disk edition is the real work: a simple content layout (a table of
names → block runs) behind the same eight verbs. Everything above it —
homes, permissions, notes, the log — runs unchanged.

### 3. Boot

GRUB/multiboot (x86_64) or a flat image for QEMU's `-kernel` (aarch64).
First milestone: Ern-OS banner over the serial port in QEMU; then the
keyboard; then the disk; then login — the same login, byte for byte.

## Order of attack, when the day comes

1. Freestanding allocator + `--freestanding` target in the language repo,
   proven by a bare `display "hello"` kernel in QEMU.
2. Serial-port editions of `the_terminal`, `the_clock`, `the_machine`.
3. RAM-disk edition of `the_disk` (loses nothing at first, persists later).
4. Boot the untouched kernel + shell on top. Login over serial.
5. Block-device persistence.

Until then, every line written above the hal is already bare-metal code —
it just doesn't know it yet.
