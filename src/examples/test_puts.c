#include <stdio.h>
#include "../clib/bdos/bdos.h"

int main(void) {
    // Output marker before calling puts
    bdos_conout('B');
    bdos_conout('E');
    bdos_conout('F');
    bdos_conout('\r');
    bdos_conout('\n');

    // Call puts
    puts("TEST");

    // Output marker after calling puts
    bdos_conout('A');
    bdos_conout('F');
    bdos_conout('T');
    bdos_conout('\r');
    bdos_conout('\n');

    // Exit
    bdos(BDOS_RESET, 0);
    return 0;
}
