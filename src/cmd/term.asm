;========================================================
; JX Monitor - Terminal Emulator Module
;========================================================
; Bridges the console to SIO Channel B, providing a
; transparent serial pass-through for attached devices.
;
; Usage: term (or e)
;   Console keystrokes are sent to SIO2 TX.
;   SIO2 RX data is displayed on the console via PUTCHAR.
;   Press ESC to exit back to monitor.
;
; Requires: SIO2_DATA, SIO2_STATUS, SIO2_RX_MASK
; Conditional: Only assembled when ENABLE_TERM=1
;========================================================

        IF ENABLE_TERM

;========================================================
; DO_TERM - Terminal emulator entry point
;========================================================
DO_TERM:
        ; Initialize SIO2 (8251 mode word + command word)
        CALL    SIO2_INIT

        LXI     H,MSG_TCON
        CALL    PRINTS

        ; --- Main poll loop ---
TERM_LP:
        ; Check console for keystroke
        CALL    CONST
        ORA     A
        JZ      TERM_RX         ; No key, check SIO2

        ; Got a key - read it
        CALL    CONIN

        ; ESC exits
        CPI     1BH
        JZ      TERM_XT

        ; Send to SIO2 TX (wait for TX ready)
        CALL    TERM_TX

        ; --- Check SIO2 for received data ---
TERM_RX:
        IN      SIO2_STATUS
        ANI     SIO2_RX_MASK
        JZ      TERM_LP         ; Nothing received, loop

        ; Read byte and display on console
        IN      SIO2_DATA
        ANI     7FH             ; Strip parity
        CALL    PUTCHAR
        JMP     TERM_LP

        ; --- Exit ---
TERM_XT:
        LXI     H,MSG_TDSC
        CALL    PRINTS
        JMP     MONITOR

;========================================================
; TERM_TX - Send A to SIO2 (with TX ready wait)
;========================================================
; Input: A = byte to transmit
; Destroys: A
;========================================================
TERM_TX:
        PUSH    PSW
TERM_TW:
        IN      SIO2_STATUS
        ANI     01H             ; TX ready (bit 0)
        JZ      TERM_TW
        POP     PSW
        OUT     SIO2_DATA
        RET

;========================================================
; Terminal emulator messages
;========================================================
MSG_TCON:
        DB      'Connected to SIO2. ESC to exit.',CR,LF,0
MSG_TDSC:
        DB      CR,LF,'Disconnected.',CR,LF,0

        ENDIF
