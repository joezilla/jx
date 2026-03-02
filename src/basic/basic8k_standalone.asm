;============================================================
; IMSAI 8K BASIC v1.4 - Standalone Build
;============================================================
; BASIC at 0000H with BIOS I/O drivers appended after RAM.
; Boots directly into BASIC interpreter.
;
; Assembled from src/basic/ directory.
; Requires assembler defines for serial/video config.
;============================================================

;--------------------------------------------------------
; BASIC interpreter (ORG 0000H, RAM at 8192)
; JXMON_BEGPR suppresses BEGPR label inside the include
; so we can define it here after the BIOS drivers.
;--------------------------------------------------------
        INCLUDE imsai_basic_8k.asm

;============================================================
; BIOS I/O routines (appended after BASIC RAM variables)
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

;--------------------------------------------------------
; Banner (PUTCHAR alias required by banner.asm)
;--------------------------------------------------------
PUTCHAR EQU B_PUTCHAR
        INCLUDE ../lib/banner.asm

;--------------------------------------------------------
; BEGPR - User programs start here (after BIOS drivers)
;--------------------------------------------------------
; 8K BASIC writes 0x00 to BEGPR-1 during RUN init (as a
; DATA statement sentinel). This byte MUST NOT overlap any
; executable code. Reserve a sacrificial padding byte.
;--------------------------------------------------------
        DB      0               ; DATA sentinel (zeroed by RUN)
BEGPR:

CODE_END:

        END
