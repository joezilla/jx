;*************************************************************
;
; Standalone Tiny BASIC for JX Monitor
;
; Load via "L" command, run via "G 0100"
;
; Requires page-zero jump table set up by JX monitor:
;   0000H = JMP WBOOT   (return to monitor)
;   0003H = JMP CONST   (console status)
;   0006H = JMP GETCHAR  (read character)
;   0009H = JMP PUTCHAR  (write character)
;
;*************************************************************

        IFNDEF BASIC_BASE
BASIC_BASE      EQU     0100H
        ENDIF
        IFNDEF BASIC_VAR
BASIC_VAR       EQU     BASIC_BASE + 0800H      ; ~2KB after code
        ENDIF
        IFNDEF BASIC_TEXT
BASIC_TEXT       EQU     BASIC_VAR + 0100H
        ENDIF

        ORG     BASIC_BASE
        INCLUDE tinybasic.asm
        END
