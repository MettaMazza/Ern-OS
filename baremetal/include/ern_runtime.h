#ifndef ERN_RUNTIME_H
#define ERN_RUNTIME_H

#include <stddef.h>

void *ern_memory_set(void *destination, int value, size_t count);
void *ern_memory_copy(void *destination, const void *source, size_t count);
size_t ern_string_length(const char *text);

void ern_heap_reset(void);
void *ern_allocate(size_t bytes);
size_t ern_heap_used(void);
size_t ern_heap_capacity(void);

/* Entry emitted from baremetal/kernel/hello.ep by `epc freestanding`. */
long long ern_freestanding_program(void);

#endif
