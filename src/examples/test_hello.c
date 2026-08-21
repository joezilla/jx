#include <stdio.h>
#include "../clib/bdos/bdos.h"

int main(void) {
    printf("Hello World!\n");
    bdos(BDOS_RESET, 0);
    return 0;
}
