;============================================================
; IMSAI 8K BASIC v1.4 - Loadable Build
;============================================================
; Assembled at ORG 0000H, calls BIOS via jump table.
; Load into memory with monitor 'l' command, run with 'g 0'.
;
; Requires BIOS_BASE defined to locate the jump table:
;   BIOS_BASE+0  = BOOT    (cold-boot / hardware reset entry)
;   BIOS_BASE+3  = WBOOT   (warm boot)
;   BIOS_BASE+6  = CONST   (console status)
;   BIOS_BASE+9  = GETCHAR (blocking read)
;   BIOS_BASE+12 = PUTCHAR (dual output)
;============================================================

;--------------------------------------------------------
; BIOS jump table entry points
;--------------------------------------------------------
        IFNDEF BIOS_BASE
BIOS_BASE  EQU  0F400H
        ENDIF

B_PUTCHAR  EQU  BIOS_BASE+12
B_GETCHAR  EQU  BIOS_BASE+9
B_CONST    EQU  BIOS_BASE+6

;--------------------------------------------------------
; BASIC interpreter (ORG 0000H)
;--------------------------------------------------------
        INCLUDE imsai_basic_8k.asm

CODE_END:

        END
