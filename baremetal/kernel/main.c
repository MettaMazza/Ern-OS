#include "ern_hal.h"
#include "ern_runtime.h"

#include <stdint.h>

#define MULTIBOOT2_BOOTLOADER_MAGIC 0x36D76289U

void ern_baremetal_main(uint32_t boot_magic, uint64_t boot_information) {
    ern_hal_terminal_start();
    ern_heap_reset();

    ern_hal_terminal_write("\n=====================================\n");
    ern_hal_terminal_write("  Ern-OS bare metal\n");
    ern_hal_terminal_write("  x86_64, no host beneath it\n");
    ern_hal_terminal_write("=====================================\n");

    if (boot_magic != MULTIBOOT2_BOOTLOADER_MAGIC) {
        ern_hal_terminal_write("BOOT ERROR: Multiboot2 handoff was not valid.\n");
        ern_hal_machine_halt();
    }

    ern_hal_terminal_write("CPU mode: long mode (64-bit)\n");
    ern_hal_terminal_write("Terminal HAL: COM1 serial\n");
    ern_hal_terminal_write("Boot information: ");
    ern_hal_terminal_write_hex(boot_information);
    ern_hal_terminal_write("\nRuntime heap: 1 MiB freestanding arena\n");
    if (ern_freestanding_program() != 1) {
        ern_hal_terminal_write("BOOT ERROR: Ernos freestanding payload failed.\n");
        ern_hal_machine_halt();
    }
    ern_hal_terminal_write("ERN-OS_BAREMETAL_OK\n");

    ern_hal_machine_halt();
}
