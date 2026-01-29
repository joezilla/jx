#include "string.h"

// Copy at most n characters from src to dest
char *strncpy(char *dest, const char *src, size_t n) {
    char *d = dest;
    size_t i;

    if (!dest || !src) return dest;

    for (i = 0; i < n && src[i]; i++) {
        dest[i] = src[i];
    }

    // Pad with nulls if src is shorter than n
    for (; i < n; i++) {
        dest[i] = '\0';
    }

    return dest;
}
