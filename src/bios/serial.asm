;========================================================
; JX Monitor - Serial Console Driver
;========================================================
; Console I/O driver with configurable port addresses
; and status register bit masks.
;
; Configuration via assembler defines:
;   SIO_DATA    - Data port (RX/TX)
;   SIO_STATUS  - Status port
;   SIO_RX_MASK - Bitmask for RX ready in status byte
;   SIO_TX_MASK - Bitmask for TX ready (0 = no TX poll)
;
; Presets:
;   cpmsim:     00H/01H, RX=FFH, TX=0 (no TX poll)
;   IMSAI 8251: 13H/12H, RX=02H, TX=01H
;========================================================

;--------------------------------------------------------
; Port and mask defaults (overridden by -d flags)
;--------------------------------------------------------
        IFNDEF SIO_DATA
SIO_DATA        EQU     01H
        ENDIF

        IFNDEF SIO_STATUS
SIO_STATUS      EQU     00H
        ENDIF

        IFNDEF SIO_RX_MASK
SIO_RX_MASK     EQU     0FFH
        ENDIF

        IFNDEF SIO_TX_MASK
SIO_TX_MASK     EQU     0
        ENDIF

        IFNDEF SIO_8251
SIO_8251        EQU     0
        ENDIF

;========================================================
; CONST - Check if character available
;========================================================
; Returns: A = 00H (no char), FFH (char ready)
; Destroys: A
;========================================================
CONST:
        IN      SIO_STATUS
        ANI     SIO_RX_MASK     ; Test RX ready bit(s)
        RZ                      ; Not ready, return 0
        MVI     A,0FFH          ; Character ready
        RET

;========================================================
; CONIN - Read character (blocking)
;========================================================
; Returns: A = character
; Destroys: A
;========================================================
CONIN:
        IN      SIO_STATUS
        ANI     SIO_RX_MASK     ; Check RX ready bit(s)
        JZ      CONIN           ; Poll until ready
        IN      SIO_DATA
        ANI     7FH             ; Strip parity bit
        RET

;========================================================
; CONOUT - Write character
;========================================================
; Input:  C = character to output
; Destroys: A
;========================================================
CONOUT:
        IF SIO_TX_MASK
COTXW:
        IN      SIO_STATUS
        ANI     SIO_TX_MASK     ; Check TX ready bit(s)
        JZ      COTXW           ; Wait for transmitter
        ENDIF
        MOV     A,C
        OUT     SIO_DATA
        RET

;========================================================
; SIO_INIT - Initialize 8251 USART
;========================================================
; Performs full 8251 reset and configuration.
; Safe from any power-on state (sync mode, mid-byte, etc).
;
; Protocol:
;   1. Three 00H writes (flush sync chars / stale state)
;   2. 40H = Internal Reset
;   3. 4EH = Mode: 16x baud, 8 data, no parity, 1 stop
;   4. 37H = Cmd:  TxEN, DTR, RxEN, ER, RTS
;
; Destroys: A
;========================================================
SIO_INIT:
        IF SIO_8251
        ; Force 8251 to known state
        XRA     A               ; A = 00H
        OUT     SIO_STATUS      ; Flush byte 1
        OUT     SIO_STATUS      ; Flush byte 2
        OUT     SIO_STATUS      ; Flush byte 3
        MVI     A,40H           ; Internal Reset
        OUT     SIO_STATUS
        ; Mode Instruction: 4EH = 01 00 11 10
        ;   01    = 1 stop bit
        ;   0     = parity type (don't care)
        ;   0     = parity disabled
        ;   11    = 8-bit characters
        ;   10    = 16x baud rate factor
        MVI     A,4EH
        OUT     SIO_STATUS
        ; Command Instruction: 37H = 00110111
        ;   TxEN=1, DTR=1, RxEN=1, SBRK=0, ER=1, RTS=1
        MVI     A,37H
        OUT     SIO_STATUS
        ENDIF
        RET

;========================================================
; End of serial.asm
;========================================================
