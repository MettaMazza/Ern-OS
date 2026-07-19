OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)

SECTIONS
{
    . = 1M;

    .multiboot ALIGN(8) :
    {
        KEEP(*(.multiboot))
    }

    .note.Xen ALIGN(4) :
    {
        KEEP(*(.note.Xen))
    }

    .text ALIGN(4K) :
    {
        *(.text.boot)
        *(.text .text.*)
    }

    .rodata ALIGN(4K) :
    {
        *(.rodata .rodata.*)
    }

    .data ALIGN(4K) :
    {
        *(.data .data.*)
    }

    .bss ALIGN(4K) (NOLOAD) :
    {
        *(COMMON)
        *(.bss .bss.*)
    }

    /DISCARD/ :
    {
        *(.comment)
        *(.eh_frame .eh_frame.*)
        *(.note.GNU-stack)
    }

    ASSERT(SIZEOF(.multiboot) == 24, "Multiboot2 header changed unexpectedly")
    ASSERT(ADDR(.multiboot) < 32K + 1M, "Multiboot2 header must remain in the first 32 KiB")
    ASSERT(_start < 0x100000000, "32-bit boot entry must remain below 4 GiB")
}
