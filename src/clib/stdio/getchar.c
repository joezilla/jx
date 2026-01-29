#include "stdio.h"
#include "../bdos/bdos.h"

int getchar(void) {
    return (int)bdos_conin();
}
