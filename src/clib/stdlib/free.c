#include "stdlib.h"

// Free allocated memory
// NOTE: Simple bump allocator doesn't support free
// This is a stub for compatibility
void free(void *ptr) {
    // Bump allocator cannot free individual blocks
    // Memory is only reclaimed when program exits
    (void)ptr;  // Unused parameter
}
