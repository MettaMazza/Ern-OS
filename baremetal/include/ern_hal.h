#ifndef ERN_HAL_H
#define ERN_HAL_H

#include <stdint.h>

void ern_hal_terminal_start(void);
void ern_hal_terminal_write(const char *text);
void ern_hal_terminal_write_hex(uint64_t value);
long long ern_baremetal_say(long long text);
void ern_hal_machine_halt(void) __attribute__((noreturn));

#endif
