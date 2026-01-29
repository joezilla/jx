#include "string.h"

// Concatenate src onto the end of dest
char *strcat(char *dest, const char *src) {
    char *d = dest;

    if (!dest || !src) return dest;

    // Find end of dest
    while (*d) {
        d++;
    }

    // Copy src to end of dest
    while ((*d++ = *src++))
        ;

    return dest;
}
