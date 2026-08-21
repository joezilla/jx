#include <stdint.h>

// Direct port output (inline assembly)
void out_char(char c) {
    __asm
        ld      a, 4(ix)  ; Get parameter from stack frame
        out     (1), a    ; Output to port 1
    __endasm;
}

int main(void) {
    // Output directly to port to bypass all library code
    out_char('M');
    out_char('A');
    out_char('I');
    out_char('N');
    out_char('\r');
    out_char('\n');

    // Exit
    __asm
        ld      c, #0x00
        call    0x0005
    __endasm;

    return 0;
}
