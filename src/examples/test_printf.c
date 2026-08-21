#include <stdio.h>
#include "../clib/bdos/bdos.h"

int main(void) {
    // Test 1: Simple string (no formatting)
    printf("A");

    // Test 2: String with newline
    printf("B\n");

    // Test 3: Longer string
    printf("HELLO");

    // Test 4: With format specifier
    printf("NUM=%d\n", 42);

    // Exit
    bdos(BDOS_RESET, 0);
    return 0;
}
