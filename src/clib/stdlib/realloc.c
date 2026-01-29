#include "stdlib.h"
#include "../string/string.h"

// Reallocate memory
// Since we use a bump allocator, we always allocate new memory and copy
void *realloc(void *ptr, size_t size) {
    void *new_ptr;

    // If ptr is NULL, behaves like malloc
    if (ptr == NULL) {
        return malloc(size);
    }

    // If size is 0, behaves like free (but we don't actually free)
    if (size == 0) {
        free(ptr);
        return NULL;
    }

    // Allocate new memory
    new_ptr = malloc(size);
    if (new_ptr == NULL) {
        return NULL;  // Allocation failed
    }

    // Copy old data to new location
    // NOTE: We don't know the old size, so we assume the user
    // is requesting a larger size and copy 'size' bytes
    // This is a limitation of the bump allocator
    memcpy(new_ptr, ptr, size);

    // Note: We can't free the old pointer with bump allocator
    // Old memory is wasted but will be reclaimed on program exit

    return new_ptr;
}
