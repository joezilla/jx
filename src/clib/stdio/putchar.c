#include "stdio.h"
#include "../bdos/bdos.h"

// Simplified putchar that calls BDOS directly
int putchar(int c) __naked {
    c; // Suppress unused warning
    __asm
        ; Parameter arrives in HL (SDCC register calling convention)
        ; Check if it's newline
        ld      a, l
        cp      #0x0A
        jr      NZ, not_newline$

        ; Output CR
        ld      e, #0x0D
        ld      c, #0x02
        push    hl
        call    0x0005
        pop     hl

        ; Output LF
        ld      e, #0x0A
        ld      c, #0x02
        call    0x0005
        ret

    not_newline$:
        ; Output character in L
        ld      e, l
        ld      c, #0x02
        call    0x0005
        ret
    __endasm;
}
