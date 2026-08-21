#include "../clib/bdos/bdos.h"

int main(void) {
    // Test calling bdos_conout wrapper
    bdos_conout('W');
    bdos_conout('R');
    bdos_conout('A');
    bdos_conout('P');
    bdos_conout('\r');
    bdos_conout('\n');

    // Exit
    bdos(BDOS_RESET, 0);

    return 0;
}
