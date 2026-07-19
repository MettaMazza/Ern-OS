# Ern-OS on bare metal

This directory contains the first freestanding x86_64 milestones. It is a real
kernel payload: GRUB enters through the Multiboot2 header in 32-bit protected
mode, `boot.S` builds identity-mapped page tables, enables long mode, and calls
the kernel without libc or a host process beneath it. The build then runs
`baremetal/kernel/hello.ep` through the real Ernos parser, semantic checker,
optimizer and C code generator and links that Ernos-authored payload into the
same ELF.

## Build and boot

The full build needs clang and `ld.lld`:

```bash
bash build_baremetal.sh
```

The boot proof additionally needs GRUB's rescue tools, xorriso and QEMU:

```bash
bash tests/test_baremetal_qemu.sh
```

On Debian/Ubuntu the prerequisites are:

```bash
sudo apt-get install clang lld grub-pc-bin grub-common xorriso qemu-system-x86
```

When only clang is available, the architecture and C sources can still be
validated as freestanding x86_64 ELF objects:

```bash
bash build_baremetal.sh --objects-only
```

When GRUB tools are present, the QEMU test builds and boots the canonical GRUB
ISO. Otherwise it uses the ELF's Xen PVH compatibility note for QEMU's direct
`-kernel` loader. Both paths enter the same page-table/long-mode bootstrap. The
test captures COM1, requires the `ERN-OS_BAREMETAL_OK` marker within ten
seconds, and then terminates that exact QEMU process. A silent hang cannot pass.

## Boundary

| path | responsibility |
|---|---|
| `x86_64/boot.S` | Multiboot2 handoff, page tables, long-mode transition, stack |
| `x86_64/linker.ld` | deterministic low-memory ELF layout |
| `hal/x86_64/terminal.c` | COM1 serial terminal contract |
| `hal/x86_64/machine.c` | interrupt-safe CPU halt contract |
| `runtime/freestanding.c` | memory/string primitives and a 1 MiB bootstrap allocator |
| `kernel/main.c` | host-free milestone kernel and serial proof |
| `kernel/hello.ep` | first Ernos-authored code executed in the kernel |

`epc freestanding program.ep` emits `program_freestanding.c` but deliberately
does not invoke the host linker. Runtime ABI v1 supports primitive values,
control flow, functions and explicit HAL externals. It provides root/collector
hooks as no-ops so primitive-only functions use the normal code generator; it
does not falsely claim support for managed lists/maps/strings, threads, hosted
files or processes. Those require the allocator/collector and scheduler
milestones below.

The Multiboot2 header follows the
[GNU Multiboot2 specification](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html):
it is 8-byte aligned, lies at the start of the linked image, carries the
required checksum and receives the boot magic in EAX and information pointer
in EBX.

## Honest status

This proves the boot path, 64-bit transition, first runtime primitives, two
hardware HAL contracts, and an Ernos frontend-to-hardware path. The hosted
Ern-OS kernel, accounts, shell, services, virtual disk, apps and graphical
desktop are **not yet executing in this image**. They still depend on managed
runtime services. The next milestone is a real freestanding collector and
cooperative scheduler, followed by a RAM-disk HAL.
