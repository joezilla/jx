#include "string.h"

// Concatenate at most n characters of src onto dest
char *strncat(char *dest, const char *src, size_t n) {
    char *d = dest;
    size_t i;

    if (!dest || !src) return dest;

    // Find end of dest
    while (*d) {
        d++;
    }

    // Copy at most n characters from src
    for (i = 0; i < n && src[i]; i++) {
        d[i] = src[i];
    }

    // Always null terminate
    d[i] = '\0';

    return dest;
}
