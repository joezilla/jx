#include "stdio.h"

int puts(const char *s) {
    if (!s) return EOF;

    while (*s) {
        putchar(*s++);
    }
    putchar('\n');
    return 0;
}
