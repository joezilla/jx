#include "stdio.h"
#include "../bdos/bdos.h"

int putchar(int c) {
    // Handle newline: output CR+LF
    if (c == '\n') {
        bdos_conout('\r');
        bdos_conout('\n');
    } else {
        bdos_conout((char)c);
    }
    return c;
}
