#include "ern_runtime.h"

#include <stdint.h>

/* The first freestanding allocator is deliberately small and deterministic.
   It establishes the runtime contract without pretending to be the hosted
   collector. A later milestone will put a collector/scheduler behind these
   calls once the untouched Ernos kernel is ready to cross this boundary. */
#define ERN_BOOT_HEAP_BYTES (1024U * 1024U)

static uint8_t ern_boot_heap[ERN_BOOT_HEAP_BYTES]
    __attribute__((aligned(16)));
static size_t ern_boot_heap_next;

void *ern_memory_set(void *destination, int value, size_t count) {
    uint8_t *out = (uint8_t *)destination;
    for (size_t i = 0; i < count; ++i) {
        out[i] = (uint8_t)value;
    }
    return destination;
}

void *ern_memory_copy(void *destination, const void *source, size_t count) {
    uint8_t *out = (uint8_t *)destination;
    const uint8_t *in = (const uint8_t *)source;
    for (size_t i = 0; i < count; ++i) {
        out[i] = in[i];
    }
    return destination;
}

size_t ern_string_length(const char *text) {
    size_t length = 0;
    if (text == NULL) {
        return 0;
    }
    while (text[length] != '\0') {
        ++length;
    }
    return length;
}

void ern_heap_reset(void) {
    ern_boot_heap_next = 0;
    ern_memory_set(ern_boot_heap, 0, sizeof(ern_boot_heap));
}

void *ern_allocate(size_t bytes) {
    if (bytes == 0) {
        return NULL;
    }
    size_t aligned = (bytes + 15U) & ~(size_t)15U;
    if (aligned < bytes || ern_boot_heap_next > ERN_BOOT_HEAP_BYTES - aligned) {
        return NULL;
    }
    void *result = &ern_boot_heap[ern_boot_heap_next];
    ern_boot_heap_next += aligned;
    ern_memory_set(result, 0, aligned);
    return result;
}

size_t ern_heap_used(void) {
    return ern_boot_heap_next;
}

size_t ern_heap_capacity(void) {
    return ERN_BOOT_HEAP_BYTES;
}

/* Compiler-emitted freestanding C may still select these conventional
   symbols for simple loops. Keep them inside the vendored runtime. */
void *memset(void *destination, int value, size_t count) {
    return ern_memory_set(destination, value, count);
}

void *memcpy(void *destination, const void *source, size_t count) {
    return ern_memory_copy(destination, source, count);
}

size_t strlen(const char *text) {
    return ern_string_length(text);
}
