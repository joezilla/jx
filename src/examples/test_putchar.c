#include <stdio.h>
#include "../clib/bdos/bdos.h"

int main(void) {
    // Test putchar directly
    putchar('P');
    putchar('U');
    putchar('T');
    putchar('\n');

    // Exit
    bdos(BDOS_RESET, 0);
    return 0;
}
