#include "bdos.h"

// Low-level BDOS call (assembly stub)
// Entry: C = function number, DE = argument
// Returns: HL = result
uint16_t bdos(uint8_t func, uint16_t arg) __naked {
    func; arg; // Suppress unused parameter warnings
    __asm
        ; SDCC calling convention for Z80:
        ; First parameter (func) is in stack
        ; Second parameter (arg) is in stack
        ; We need to set up: C = func, DE = arg

        pop     hl              ; Return address
        pop     de              ; DE = arg (16-bit)
        pop     bc              ; BC = func (only C is used)
        push    bc              ; Restore stack
        push    de
        push    hl

        ; Call BDOS at 0x0005
        call    0x0005

        ; Return value is already in HL
        ret
    __endasm;
}

// Console input - wait for character
uint8_t bdos_conin(void) {
    return (uint8_t)bdos(BDOS_CONIN, 0);
}

// Console output - write single character
void bdos_conout(char c) {
    bdos(BDOS_CONOUT, (uint16_t)c);
}

// Print $ terminated string
void bdos_print(const char *str) {
    // BDOS function 9 expects DE = address of $ terminated string
    bdos(BDOS_PRINT, (uint16_t)str);
}

// Console status - check if character ready
// Returns: 0xFF if character ready, 0x00 otherwise
uint8_t bdos_const(void) {
    return (uint8_t)bdos(BDOS_CONST, 0);
}

// Get TPA top address
uint16_t bdos_gettpa(void) {
    return bdos(BDOS_GETTPA, 0);
}

// Get total memory size in KB
uint16_t bdos_getmem(void) {
    return bdos(BDOS_GETMEM, 0);
}
