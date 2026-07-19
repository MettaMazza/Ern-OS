#include "ern_hal.h"

void ern_hal_machine_halt(void) {
    for (;;) {
        __asm__ volatile("cli; hlt");
    }
}
