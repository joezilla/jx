#include "string.h"

// Find first occurrence of character c in string s
char *strchr(const char *s, int c) {
    char ch = (char)c;

    if (!s) return NULL;

    while (*s) {
        if (*s == ch) {
            return (char *)s;
        }
        s++;
    }

    // Check for null terminator match
    if (ch == '\0') {
        return (char *)s;
    }

    return NULL;
}
