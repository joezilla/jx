#include "string.h"

// Copy n bytes from src to dest
// Note: dest and src must not overlap (use memmove for overlapping regions)
void *memcpy(void *dest, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;

    if (!dest || !src) return dest;

    while (n--) {
        *d++ = *s++;
    }

    return dest;
}
