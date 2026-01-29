#include "stdio.h"

// Read a line from stdin
// WARNING: This is unsafe (no bounds checking) - deprecated in C11
// But it's simple for our purposes
char *gets(char *s) {
    char *p = s;
    int c;

    if (!s) return NULL;

    while (1) {
        c = getchar();

        // Handle line ending
        if (c == '\n' || c == '\r' || c == EOF) {
            *p = '\0';
            return (c == EOF && p == s) ? NULL : s;
        }

        // Handle backspace
        if (c == '\b' || c == 0x7F) {
            if (p > s) {
                p--;
                // Echo backspace sequence
                putchar('\b');
                putchar(' ');
                putchar('\b');
            }
            continue;
        }

        // Store character
        *p++ = (char)c;

        // Echo character
        putchar(c);
    }
}
