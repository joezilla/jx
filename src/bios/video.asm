;========================================================
; JX Monitor - VDM-1 Video Framebuffer Driver
;========================================================
; Memory-mapped character display driver for the
; Processor Technology VDM-1.
;
; 64 columns x 16 rows = 1024 bytes at C000H-C3FFH.
; Pure memory-mapped framebuffer (write ASCII bytes
; directly). No hardware scrolling - software scroll.
;
; The video base address is configurable via VIDEO_BASE.
; Set VIDEO_BASE=0 to disable video support entirely.
;
; This module is INCLUDEd by bios.asm.
;========================================================

;--------------------------------------------------------
; Video Configuration Defaults
; These can be overridden via assembler -d flags.
;--------------------------------------------------------
        IFNDEF VIDEO_BASE
VIDEO_BASE      EQU     0C000H  ; VDM-1 default
        ENDIF

        IFNDEF VIDEO_CTRL
VIDEO_CTRL      EQU     0C8H    ; VDM-1 control port
        ENDIF

        IFNDEF VIDEO_COLS
VIDEO_COLS      EQU     64      ; VDM-1: 64 columns
        ENDIF

        IFNDEF VIDEO_ROWS
VIDEO_ROWS      EQU     16      ; VDM-1: 16 rows
        ENDIF

; Derived constants
VIDEO_SIZE      EQU     VIDEO_COLS * VIDEO_ROWS
LAST_ROW_ADDR   EQU     VIDEO_BASE + (VIDEO_COLS * (VIDEO_ROWS - 1))

;========================================================
; Video state variables
;========================================================
V_CURROW:       DB      0       ; Current cursor row (0-15)
V_CURCOL:       DB      0       ; Current cursor column (0-63)

;========================================================
; V_INIT - Initialize video display
;========================================================
; Clears screen and homes cursor.
; Destroys: A, B, C, D, E, H, L
;========================================================
V_INIT:
        IF VIDEO_BASE
        XRA     A
        OUT     VIDEO_CTRL      ; Initialize VDM-1 control register
        CALL    V_CLEAR
        XRA     A
        STA     V_CURROW
        STA     V_CURCOL
        ENDIF
        RET

;========================================================
; V_CLEAR - Clear entire screen (fill with spaces)
;========================================================
; Destroys: A, B, C, H, L
;========================================================
V_CLEAR:
        IF VIDEO_BASE
        LXI     H,VIDEO_BASE
        LXI     B,VIDEO_SIZE
        MVI     A,' '
VCLR1:
        MOV     M,A
        INX     H
        DCX     B
        MOV     A,B
        ORA     C
        MVI     A,' '           ; Reload space (ORA destroys A)
        JNZ     VCLR1
        ENDIF
        RET

;========================================================
; V_PUTCH - Write character at cursor, advance cursor
;========================================================
; Input:  A = character to write
; Handles: CR, LF, BS, TAB, and printable characters
; Destroys: A, B, C, D, E, H, L
;========================================================
V_PUTCH:
        IF VIDEO_BASE
        ; Handle control characters
        CPI     0DH             ; CR
        JZ      V_CR
        CPI     0AH             ; LF
        JZ      V_LF
        CPI     08H             ; BS
        JZ      V_BS
        CPI     09H             ; TAB
        JZ      V_TAB
        CPI     20H             ; Below space?
        RC                      ; Ignore other control chars

        ; Printable character - write to framebuffer
        PUSH    PSW             ; Save character
        CALL    V_CURADDR       ; HL = cursor address in framebuffer
        POP     PSW
        MOV     M,A             ; Write character to screen

        ; Advance cursor
        LDA     V_CURCOL
        INR     A
        CPI     VIDEO_COLS      ; Past end of line?
        JC      VPUT2
        ; Wrap to next line
        XRA     A               ; Column = 0
        STA     V_CURCOL
        JMP     V_LF            ; Line feed (handles scroll)
VPUT2:
        STA     V_CURCOL
        ENDIF
        RET

;========================================================
; V_CR - Carriage return (move cursor to column 0)
;========================================================
V_CR:
        IF VIDEO_BASE
        XRA     A
        STA     V_CURCOL
        ENDIF
        RET

;========================================================
; V_LF - Line feed (move cursor down, scroll if needed)
;========================================================
V_LF:
        IF VIDEO_BASE
        LDA     V_CURROW
        INR     A
        CPI     VIDEO_ROWS      ; Past bottom?
        JC      VLF2
        ; Need to scroll
        CALL    V_SCROLL
        MVI     A,VIDEO_ROWS-1  ; Stay on last row
VLF2:
        STA     V_CURROW
        ENDIF
        RET

;========================================================
; V_BS - Backspace (move cursor left, don't erase)
;========================================================
V_BS:
        IF VIDEO_BASE
        LDA     V_CURCOL
        ORA     A
        RZ                      ; Already at column 0
        DCR     A
        STA     V_CURCOL
        ENDIF
        RET

;========================================================
; V_TAB - Tab (advance to next 8-column boundary)
;========================================================
V_TAB:
        IF VIDEO_BASE
        LDA     V_CURCOL
        ORI     07H             ; Round up to next 8
        INR     A
        CPI     VIDEO_COLS
        JNC     VTAB2           ; Past end of line
        STA     V_CURCOL
        RET
VTAB2:
        ; Tab wrapped past end of line
        XRA     A
        STA     V_CURCOL
        JMP     V_LF
        ENDIF
        RET

;========================================================
; V_SCROLL - Scroll screen up one line
;========================================================
; Copies rows 1..15 to rows 0..14, clears last row.
; Destroys: A, B, C, D, E, H, L
;========================================================
V_SCROLL:
        IF VIDEO_BASE
        ; Copy row 1 to row 0, row 2 to row 1, etc.
        LXI     D,VIDEO_BASE                ; Destination (row 0)
        LXI     H,VIDEO_BASE+VIDEO_COLS     ; Source (row 1)
        LXI     B,VIDEO_COLS*(VIDEO_ROWS-1) ; Bytes to copy
VSCL1:
        MOV     A,M             ; Read from source
        STAX    D               ; Write to destination
        INX     H
        INX     D
        DCX     B
        MOV     A,B
        ORA     C
        JNZ     VSCL1

        ; Clear last row
        LXI     H,LAST_ROW_ADDR
        MVI     B,VIDEO_COLS
        MVI     A,' '
VSCL2:
        MOV     M,A
        INX     H
        DCR     B
        JNZ     VSCL2
        ENDIF
        RET

;========================================================
; V_CURADDR - Calculate framebuffer address of cursor
;========================================================
; Output: HL = VIDEO_BASE + (row * VIDEO_COLS) + col
; Destroys: A, D, E
;========================================================
V_CURADDR:
        IF VIDEO_BASE
        ; HL = row * 64
        ; Method: row * 64 = shift left 6 times
        LDA     V_CURROW
        MOV     L,A
        MVI     H,0             ; HL = row
        DAD     H               ; HL = row*2
        DAD     H               ; HL = row*4
        DAD     H               ; HL = row*8
        DAD     H               ; HL = row*16
        DAD     H               ; HL = row*32
        DAD     H               ; HL = row*64

        ; Add column
        LDA     V_CURCOL
        MOV     E,A
        MVI     D,0
        DAD     D               ; HL = row*64 + col

        ; Add video base
        LXI     D,VIDEO_BASE
        DAD     D               ; HL = VIDEO_BASE + offset
        ENDIF
        RET

;========================================================
; End of video.asm
;========================================================
