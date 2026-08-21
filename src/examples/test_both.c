#include <stdio.h>
#include "../clib/bdos/bdos.h"

int main(void) {
    // Test 1: Direct bdos_conout (we know this works)
    bdos_conout('D');
    bdos_conout('I');
    bdos_conout('R');
    bdos_conout('\r');
    bdos_conout('\n');

    // Test 2: Using putchar
    putchar('P');
    putchar('U');
    putchar('T');
    putchar('\r');
    putchar('\n');

    // Exit
    bdos(BDOS_RESET, 0);
    return 0;
}
