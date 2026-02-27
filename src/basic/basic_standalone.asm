;============================================================
; Altair BASIC 3.2 - Standalone Build
;============================================================
; BASIC at 0000H with BIOS I/O drivers appended.
; Boots directly into BASIC interpreter.
;
; Assembled from src/basic/ directory.
; Requires assembler defines for serial/video config.
;============================================================

;--------------------------------------------------------
; BASIC interpreter (ORG 0000H)
;--------------------------------------------------------
        INCLUDE altair_basic.asm

;============================================================
; BIOS I/O routines (appended after BASIC code)
;============================================================

;--------------------------------------------------------
; B_PUTCHAR - Dual output (serial + video)
;--------------------------------------------------------
; Input: A = character to output
;--------------------------------------------------------
B_PUTCHAR:
        PUSH    PSW
        PUSH    H
        MOV     C,A
        CALL    CONOUT
        IF VIDEO_BASE
        POP     H
        POP     PSW
        PUSH    PSW
        PUSH    H
        PUSH    D               ; V_PUTCH destroys DE
        PUSH    B
        CALL    V_PUTCH
        POP     B
        POP     D
        ENDIF
        POP     H
        POP     PSW
        RET

;--------------------------------------------------------
; B_GETCHAR - Blocking read from serial
;--------------------------------------------------------
; Output: A = character
;--------------------------------------------------------
B_GETCHAR:
        CALL    CONIN
        RET

;--------------------------------------------------------
; B_CONST - Console status check
;--------------------------------------------------------
; Output: A = 00H (no char), FFH (char ready)
;--------------------------------------------------------
B_CONST:
        JMP     CONST

;--------------------------------------------------------
; Include BIOS drivers
;--------------------------------------------------------
        INCLUDE ../bios/serial.asm
        INCLUDE ../bios/video.asm

CODE_END:

        END
