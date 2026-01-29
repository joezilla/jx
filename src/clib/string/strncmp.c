#include "string.h"

// Compare at most n characters of two strings
// Returns: < 0 if s1 < s2, 0 if s1 == s2, > 0 if s1 > s2
int strncmp(const char *s1, const char *s2, size_t n) {
    if (n == 0) return 0;
    if (!s1 || !s2) {
        if (s1 == s2) return 0;
        return s1 ? 1 : -1;
    }

    while (n > 0 && *s1 && (*s1 == *s2)) {
        s1++;
        s2++;
        n--;
    }

    if (n == 0) return 0;

    return (unsigned char)*s1 - (unsigned char)*s2;
}
