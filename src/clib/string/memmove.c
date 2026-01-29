#include "string.h"

// Copy n bytes from src to dest, handling overlapping regions correctly
void *memmove(void *dest, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;

    if (!dest || !src || n == 0) return dest;

    // Check if regions overlap and copy direction matters
    if (d < s) {
        // Copy forward
        while (n--) {
            *d++ = *s++;
        }
    } else {
        // Copy backward to handle overlap
        d += n;
        s += n;
        while (n--) {
            *--d = *--s;
        }
    }

    return dest;
}
