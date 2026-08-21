#include <stdio.h>
#include "../clib/bdos/bdos.h"

int main(void) {
    // Direct BDOS call test
    bdos_conout('T');
    bdos_conout('E');
    bdos_conout('S');
    bdos_conout('T');
    bdos_conout('\r');
    bdos_conout('\n');

    // Printf test
    printf("Hello from test_print!\n");

    // Exit
    bdos(BDOS_RESET, 0);
    return 0;
}
