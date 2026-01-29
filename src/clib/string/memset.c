#include "string.h"

// Fill n bytes of memory with constant byte c
void *memset(void *s, int c, size_t n) {
    unsigned char *p = (unsigned char *)s;
    unsigned char value = (unsigned char)c;

    if (!s) return s;

    while (n--) {
        *p++ = value;
    }

    return s;
}
