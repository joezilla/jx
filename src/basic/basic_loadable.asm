;============================================================
; Altair BASIC 3.2 - Loadable Build
;============================================================
; Assembled at ORG 0000H, calls BIOS via jump table.
; Load into memory with monitor 'l' command, run with 'g 0'.
;
; Requires BIOS_BASE defined to locate the jump table:
;   BIOS_BASE+3 = CONST  (console status)
;   BIOS_BASE+6 = GETCHAR (blocking read)
;   BIOS_BASE+9 = PUTCHAR (dual output)
;============================================================

;--------------------------------------------------------
; BIOS jump table entry points
;--------------------------------------------------------
        IFNDEF BIOS_BASE
BIOS_BASE  EQU  0F400H
        ENDIF

B_PUTCHAR  EQU  BIOS_BASE+9
B_GETCHAR  EQU  BIOS_BASE+6
B_CONST    EQU  BIOS_BASE+3

;--------------------------------------------------------
; BASIC interpreter (ORG 0000H)
;--------------------------------------------------------
        INCLUDE altair_basic.asm

CODE_END:

        END
