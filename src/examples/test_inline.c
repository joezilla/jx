// Test with inline BDOS calls to bypass wrapper functions

int main(void) {
    // Output 'I' directly via BDOS using inline assembly
    __asm
        ld      e, #'I'
        ld      c, #0x02
        call    0x0005
    __endasm;

    // Output 'N'
    __asm
        ld      e, #'N'
        ld      c, #0x02
        call    0x0005
    __endasm;

    // Output 'L'
    __asm
        ld      e, #'L'
        ld      c, #0x02
        call    0x0005
    __endasm;

    // Output '\r'
    __asm
        ld      e, #0x0D
        ld      c, #0x02
        call    0x0005
    __endasm;

    // Output '\n'
    __asm
        ld      e, #0x0A
        ld      c, #0x02
        call    0x0005
    __endasm;

    // Exit
    __asm
        ld      c, #0x00
        call    0x0005
    __endasm;

    return 0;
}
