#include "stdlib.h"
#include "../string/string.h"

// Allocate and zero-initialize memory
void *calloc(size_t nmemb, size_t size) {
    size_t total;
    void *ptr;

    // Check for overflow
    if (nmemb == 0 || size == 0) {
        return NULL;
    }

    total = nmemb * size;

    // Simple overflow check (not perfect but better than nothing)
    if (total / nmemb != size) {
        return NULL;  // Overflow detected
    }

    // Allocate memory
    ptr = malloc(total);
    if (ptr == NULL) {
        return NULL;
    }

    // Zero-initialize
    memset(ptr, 0, total);

    return ptr;
}
