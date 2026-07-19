#include "ern_hal.h"

#include <stdint.h>

#define ERN_COM1 0x3F8U

static inline void ern_out8(uint16_t port, uint8_t value) {
    __asm__ volatile("outb %0, %1" : : "a"(value), "Nd"(port));
}

static inline uint8_t ern_in8(uint16_t port) {
    uint8_t value;
    __asm__ volatile("inb %1, %0" : "=a"(value) : "Nd"(port));
    return value;
}

static void ern_serial_letter(char letter) {
    while ((ern_in8(ERN_COM1 + 5U) & 0x20U) == 0U) {
        __asm__ volatile("pause");
    }
    ern_out8(ERN_COM1, (uint8_t)letter);
}

void ern_hal_terminal_start(void) {
    ern_out8(ERN_COM1 + 1U, 0x00U);
    ern_out8(ERN_COM1 + 3U, 0x80U);
    ern_out8(ERN_COM1 + 0U, 0x03U);
    ern_out8(ERN_COM1 + 1U, 0x00U);
    ern_out8(ERN_COM1 + 3U, 0x03U);
    ern_out8(ERN_COM1 + 2U, 0xC7U);
    ern_out8(ERN_COM1 + 4U, 0x0BU);
}

void ern_hal_terminal_write(const char *text) {
    if (text == 0) {
        return;
    }
    while (*text != '\0') {
        if (*text == '\n') {
            ern_serial_letter('\r');
        }
        ern_serial_letter(*text);
        ++text;
    }
}

void ern_hal_terminal_write_hex(uint64_t value) {
    static const char digits[] = "0123456789abcdef";
    ern_hal_terminal_write("0x");
    for (int shift = 60; shift >= 0; shift -= 4) {
        ern_serial_letter(digits[(value >> (unsigned)shift) & 0x0FU]);
    }
}

/* Stable FFI bridge used by Ernos-authored freestanding programs. */
long long ern_baremetal_say(long long text) {
    if (text == 0) {
        return 0;
    }
    ern_hal_terminal_write((const char *)(uintptr_t)text);
    return 1;
}
