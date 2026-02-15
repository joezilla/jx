;========================================================
; JX Operating System - String Operations
;========================================================
; String manipulation routines.
; All strings are null-terminated unless noted.
;========================================================

;========================================================
; STRLEN - Get string length
; Input:  HL = address of null-terminated string
; Output: BC = length (not counting null)
; Destroys: A, B, C
;========================================================
STRLEN:
        PUSH    H
        LXI     B,0             ; Length counter = 0
STRL1:
        MOV     A,M             ; Get character
        ORA     A               ; Check for null
        JZ      STRL2           ; Done
        INX     H               ; Next char
        INX     B               ; Increment count
        JMP     STRL1
STRL2:
        POP     H
        RET

;========================================================
; STRCMP - Compare two strings
; Input:  HL = string 1, DE = string 2
; Output: Z flag set if equal, NZ if different
;         A = 0 if equal
; Destroys: A
;========================================================
STRCMP:
        PUSH    H
        PUSH    D
SCMP1:
        LDAX    D               ; Get char from string 2
        CMP     M               ; Compare with string 1
        JNZ     SCMP2           ; Not equal
        ORA     A               ; Both null? (end of strings)
        JZ      SCMP2           ; Equal - done
        INX     H
        INX     D
        JMP     SCMP1
SCMP2:
        POP     D
        POP     H
        RET                     ; Z flag reflects result

;========================================================
; STRCPY - Copy string
; Input:  HL = source string, DE = destination
; Destroys: A
;========================================================
STRCPY:
        PUSH    H
        PUSH    D
SCPY1:
        MOV     A,M             ; Get source char
        STAX    D               ; Store to dest
        ORA     A               ; Check for null
        JZ      SCPY2           ; Done
        INX     H               ; Next source
        INX     D               ; Next dest
        JMP     SCPY1
SCPY2:
        POP     D
        POP     H
        RET

;========================================================
; STRTOUPPER - Convert string to uppercase in-place
; Input:  HL = null-terminated string
; Destroys: A
;========================================================
STRTOUPPER:
        PUSH    H
STUP1:
        MOV     A,M
        ORA     A
        JZ      STUP2           ; End of string
        CPI     'a'
        JC      STUP3           ; Below 'a'
        CPI     'z'+1
        JNC     STUP3           ; Above 'z'
        SUI     20H             ; Convert to uppercase
        MOV     M,A
STUP3:
        INX     H
        JMP     STUP1
STUP2:
        POP     H
        RET

;========================================================
; End of string.asm
;========================================================
