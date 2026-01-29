#include "string.h"

// Calculate length of string
size_t strlen(const char *s) {
    const char *p = s;

    if (!s) return 0;

    while (*p) {
        p++;
    }

    return (size_t)(p - s);
}
