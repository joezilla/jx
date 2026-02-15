;========================================================
; JX Monitor - Print Routines
;========================================================
; Output routines for strings and numbers.
; All output goes through PUTCHAR (defined in bios.asm)
; which sends to both serial and video.
;========================================================

;========================================================
; PRINTS - Print null-terminated string
; Input:  HL = address of null-terminated string
; Destroys: A, C, H, L
;========================================================
PRINTS:
        MOV     A,M             ; Get character
        ORA     A               ; Check for null
        RZ                      ; Return if end of string
        CALL    PUTCHAR
        INX     H               ; Next character
        JMP     PRINTS

;========================================================
; PRCRLF - Print carriage return + line feed
; Destroys: A, C
;========================================================
PRCRLF:
        MVI     A,CR
        CALL    PUTCHAR
        MVI     A,LF
        CALL    PUTCHAR
        RET

;========================================================
; PRHEX8 - Print A as 2-digit hex
; Input:  A = byte to print
; Destroys: A, C
;========================================================
PRHEX8:
        PUSH    PSW             ; Save original byte
        RRC                     ; Shift high nibble down
        RRC
        RRC
        RRC
        CALL    PRNIB           ; Print high nibble
        POP     PSW             ; Restore original
        CALL    PRNIB           ; Print low nibble
        RET

;========================================================
; PRNIB - Print low nibble of A as hex digit
; Input:  A = value (low 4 bits used)
; Destroys: A, C
;========================================================
PRNIB:
        ANI     0FH             ; Mask to low nibble
        CPI     10
        JC      PRNIB1          ; 0-9
        ADI     'A'-10          ; A-F
        JMP     PRNIB2
PRNIB1:
        ADI     '0'             ; 0-9
PRNIB2:
        CALL    PUTCHAR
        RET

;========================================================
; PRHEX16 - Print HL as 4-digit hex
; Input:  HL = 16-bit value
; Destroys: A, C
;========================================================
PRHEX16:
        MOV     A,H
        CALL    PRHEX8
        MOV     A,L
        CALL    PRHEX8
        RET

;========================================================
; PRDEC8 - Print A as decimal (0-255)
; Input:  A = number to print
; Destroys: A, B, C
;========================================================
PRDEC8:
        ; Handle hundreds digit
        MVI     B,0             ; Hundreds counter
PRDH:
        CPI     100
        JC      PRD8T           ; Less than 100
        SUI     100
        INR     B
        JMP     PRDH
PRD8T:
        PUSH    PSW             ; Save remainder
        MOV     A,B
        ORA     A
        JZ      PRDSKH          ; Skip leading zero
        ADI     '0'
        CALL    PUTCHAR
        ; Tens digit (must print even if zero after hundreds)
        POP     PSW
        MVI     B,0
PRD8T2:
        CPI     10
        JC      PRD8O2
        SUI     10
        INR     B
        JMP     PRD8T2
PRD8O2:
        PUSH    PSW
        MOV     A,B
        ADI     '0'
        CALL    PUTCHAR
        POP     PSW
        ADI     '0'
        CALL    PUTCHAR
        RET

PRDSKH:
        POP     PSW             ; Restore remainder (no hundreds)
        ; Tens digit
        MVI     B,0
PRD8T3:
        CPI     10
        JC      PRD8O3
        SUI     10
        INR     B
        JMP     PRD8T3
PRD8O3:
        PUSH    PSW
        MOV     A,B
        ORA     A
        JZ      PRDSKO          ; Skip leading zero
        ADI     '0'
        CALL    PUTCHAR
PRDSKO:
        POP     PSW
        ADI     '0'
        CALL    PUTCHAR
        RET

;========================================================
; PRDEC16 - Print HL as unsigned decimal (0-65535)
; Input:  HL = 16-bit value
; Destroys: A, B, C, D, E, H, L
;========================================================
PRDEC16:
        PUSH    B
        MVI     B,0             ; Leading zero flag (0=suppress)

        LXI     D,10000
        CALL    PR16DIG
        LXI     D,1000
        CALL    PR16DIG
        LXI     D,100
        CALL    PR16DIG
        LXI     D,10
        CALL    PR16DIG

        ; Last digit - always print
        MOV     A,L
        ADI     '0'
        CALL    PUTCHAR

        POP     B
        RET

;--------------------------------------------------------
; PR16DIG - Print one decimal digit (helper for PRDEC16)
; Input:  HL = value, DE = divisor, B = leading zero flag
; Output: HL = remainder, B updated
; Destroys: A, C, D, E
;--------------------------------------------------------
PR16DIG:
        MVI     C,0             ; Digit counter
PR16LP:
        ; Subtract DE from HL
        MOV     A,L
        SUB     E
        MOV     L,A
        MOV     A,H
        SBB     D
        MOV     H,A
        JC      PR16DN          ; Went negative, done
        INR     C
        JMP     PR16LP
PR16DN:
        ; Add DE back (we subtracted one too many)
        MOV     A,L
        ADD     E
        MOV     L,A
        MOV     A,H
        ADC     D
        MOV     H,A

        ; Check if we should print this digit
        MOV     A,C
        ORA     A
        JNZ     PR16PR          ; Non-zero digit, print it
        MOV     A,B
        ORA     A
        RZ                      ; Leading zero, suppress

PR16PR:
        MOV     A,C
        ADI     '0'
        PUSH    H
        CALL    PUTCHAR
        POP     H
        MVI     B,1             ; No more leading zero suppression
        RET

;========================================================
; PRSPC - Print a space
; Destroys: A, C
;========================================================
PRSPC:
        MVI     A,' '
        CALL    PUTCHAR
        RET

;========================================================
; End of print.asm
;========================================================
