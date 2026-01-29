#include "string.h"

// Find last occurrence of character c in string s
char *strrchr(const char *s, int c) {
    char ch = (char)c;
    const char *last = NULL;

    if (!s) return NULL;

    // Scan entire string, remembering last match
    while (*s) {
        if (*s == ch) {
            last = s;
        }
        s++;
    }

    // Check for null terminator match
    if (ch == '\0') {
        return (char *)s;
    }

    return (char *)last;
}
