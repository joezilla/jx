#include "string.h"

// Compare n bytes of two memory regions
// Returns: < 0 if s1 < s2, 0 if s1 == s2, > 0 if s1 > s2
int memcmp(const void *s1, const void *s2, size_t n) {
    const unsigned char *p1 = (const unsigned char *)s1;
    const unsigned char *p2 = (const unsigned char *)s2;

    if (!s1 || !s2) {
        if (s1 == s2) return 0;
        return s1 ? 1 : -1;
    }

    while (n--) {
        if (*p1 != *p2) {
            return *p1 - *p2;
        }
        p1++;
        p2++;
    }

    return 0;
}
