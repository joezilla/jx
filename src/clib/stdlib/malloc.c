#include "stdlib.h"
#include <stdint.h>

// External symbols from crt0.s and linker
extern uint8_t heap_start;      // Start of heap (from _HEAP area)
extern uint16_t tpa_top;        // TPA top address (saved in crt0)

// Heap state
static uint8_t *heap_ptr = NULL;    // Current heap pointer
static uint16_t heap_end = 0;       // End of heap (stack - safety margin)

// Stack safety margin (bytes to leave for stack)
#define STACK_MARGIN 256

// Initialize heap
// Called from crt0.s before main()
void heap_init(void) {
    heap_ptr = &heap_start;
    heap_end = tpa_top - STACK_MARGIN;
}

// Simple bump allocator
// Allocates size bytes and returns pointer, or NULL on failure
void *malloc(size_t size) {
    uint8_t *ptr;

    // Sanity checks
    if (size == 0) return NULL;
    if (heap_ptr == NULL) return NULL;  // Not initialized

    // Align size to 2-byte boundary for better performance
    if (size & 1) size++;

    // Check if we have enough space
    if ((uint16_t)heap_ptr + size >= heap_end) {
        return NULL;  // Out of memory
    }

    // Allocate memory
    ptr = heap_ptr;
    heap_ptr += size;

    return ptr;
}

// Get current heap usage
size_t heap_used(void) {
    if (heap_ptr == NULL) return 0;
    return (size_t)(heap_ptr - &heap_start);
}

// Get available heap space
size_t heap_available(void) {
    if (heap_ptr == NULL) return 0;
    if ((uint16_t)heap_ptr >= heap_end) return 0;
    return (size_t)(heap_end - (uint16_t)heap_ptr);
}
