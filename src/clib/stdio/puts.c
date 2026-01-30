#include "stdio.h"

int puts(const char *s) {
    // DEBUG: Output marker to show we entered puts
    __asm
        ld      a, #'{'
        out     (1), a
    __endasm;

    if (!s) return EOF;

    while (*s) {
        putchar(*s++);
    }
    putchar('\n');

    // DEBUG: Output marker to show we're exiting puts
    __asm
        ld      a, #'}'
        out     (1), a
    __endasm;

    return 0;
}
