#include "string.h"

// Copy string from src to dest
char *strcpy(char *dest, const char *src) {
    char *d = dest;

    if (!dest || !src) return dest;

    while ((*d++ = *src++))
        ;

    return dest;
}
