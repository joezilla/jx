#include "string.h"

// Compare two strings
// Returns: < 0 if s1 < s2, 0 if s1 == s2, > 0 if s1 > s2
int strcmp(const char *s1, const char *s2) {
    if (!s1 || !s2) {
        if (s1 == s2) return 0;
        return s1 ? 1 : -1;
    }

    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }

    return (unsigned char)*s1 - (unsigned char)*s2;
}
