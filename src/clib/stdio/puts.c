#include "stdio.h"

// Rewrite puts as naked function to avoid any calling issues
int puts(const char *s) __naked {
    s; // Suppress unused warning
    __asm
        ; Parameter (string pointer) arrives in HL
        ; Check for NULL
        ld      a, h
        or      a, l
        jr      NZ, not_null$

        ; Return EOF (-1) in DE
        ld      de, #0xFFFF
        ret

    not_null$:
        ; Save string pointer in DE for the loop
        ex      de, hl          ; DE = string pointer

    loop$:
        ; Load character from string
        ld      a, (de)
        or      a, a            ; Check for null terminator
        jr      Z, end_of_string$

        ; Output character
        push    de              ; Save string pointer
        ld      l, a            ; Character in HL for putchar
        ld      h, #0x00
        call    _putchar
        pop     de              ; Restore string pointer

        ; Increment pointer
        inc     de
        jr      loop$

    end_of_string$:
        ; Output newline
        ld      hl, #0x000A
        call    _putchar

        ; Return 0
        ld      de, #0x0000
        ret
    __endasm;
}
