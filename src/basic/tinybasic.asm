;*************************************************************
;
;                     T B I
;            TINY BASIC INTERPRETER
;                 VERSION 3.0
;               FOR 8080 SYSTEM
;                 LI-CHEN WANG
;                26 APRIL, 1977
;
;            Ported to z80asm syntax
;            for JX Monitor, 2026
;
;                  @COPYLEFT
;               ALL WRONGS RESERVED
;
;*************************************************************
;
; Requires these EQUs defined before INCLUDE:
;   BASIC_VAR   - Start of variable/stack area (~256 bytes)
;   BASIC_TEXT   - Start of BASIC program text area
;
; When included from bios.asm, ENABLE_BASIC must be defined.
; When assembled standalone, ENABLE_BASIC is not defined
; and all code is included unconditionally.
;
; I/O goes through page-zero jump table:
;   0000H = JMP WBOOT  (return to monitor)
;   0003H = JMP CONST  (console status: A=FFH/00H)
;   0006H = JMP GETCHAR (read char: A=char)
;   0009H = JMP PUTCHAR (write char: A=char)
;
;*************************************************************

; Guard for conditional inclusion from bios.asm.
; Standalone builds don't define ENABLE_BASIC, so default to 1.
        IFNDEF ENABLE_BASIC
ENABLE_BASIC    EQU     1
        ENDIF

        IF ENABLE_BASIC

;-------------------------------------------------------------
; DWA macro - store address with bit 7 set in high byte
; Used in command/function dispatch tables
;-------------------------------------------------------------
DWA     MACRO WHERE
        DB   (WHERE SHR 8) + 128
        DB   WHERE AND 0FFH
        ENDM

;-------------------------------------------------------------
; CR/LF constants (use IFNDEF to avoid conflict with bios.asm)
;-------------------------------------------------------------
        IFNDEF CR
CR      EQU     0DH
        ENDIF
        IFNDEF LF
LF      EQU     0AH
        ENDIF

;-------------------------------------------------------------
; RAM Variables (EQU-based, no ORG needed)
;-------------------------------------------------------------
TB_KEYWRD       EQU     BASIC_VAR+0     ; Cold-start flag (1 byte)
TB_TXTLMT       EQU     BASIC_VAR+1     ; -> limit of text area (2 bytes)
TB_VARBGN       EQU     BASIC_VAR+3     ; Variables A-Z (52 bytes)
TB_CURRNT       EQU     BASIC_VAR+55    ; -> current line (2 bytes)
TB_STKGOS       EQU     BASIC_VAR+57    ; Saves SP in GOSUB (2 bytes)
TB_VARNXT       EQU     BASIC_VAR+59    ; Temp storage (2 bytes)
TB_STKINP       EQU     BASIC_VAR+61    ; Saves SP in INPUT (2 bytes)
TB_LOPVAR       EQU     BASIC_VAR+63    ; FOR loop var addr (2 bytes)
TB_LOPINC       EQU     BASIC_VAR+65    ; FOR increment (2 bytes)
TB_LOPLMT       EQU     BASIC_VAR+67    ; FOR limit (2 bytes)
TB_LOPLN        EQU     BASIC_VAR+69    ; FOR line number (2 bytes)
TB_LOPPT        EQU     BASIC_VAR+71    ; FOR text pointer (2 bytes)
TB_RANPNT       EQU     BASIC_VAR+73    ; Random number pointer (2 bytes)
TB_BUFFER       EQU     BASIC_VAR+76    ; Input buffer (132 bytes)
TB_BUFEND       EQU     BASIC_VAR+208   ; Buffer end marker
TB_STKLMT       EQU     BASIC_VAR+212   ; Soft limit for stack
TB_STACK        EQU     BASIC_VAR+256   ; Stack (grows down from here)

; Text save area
TB_TXTUNF       EQU     BASIC_TEXT+0    ; -> unfilled text area (2 bytes)
TB_TEXT         EQU     BASIC_TEXT+2    ; Text save area begins

;*************************************************************
;
; *** I/O ROUTINES ***
;
; These use the page-zero jump table set up by the JX monitor.
;
;*************************************************************

;-------------------------------------------------------------
; TB_CRLF - Output CR+LF
;-------------------------------------------------------------
TB_CRLF:
        MVI     A,CR

;-------------------------------------------------------------
; TB_OUTCH - Output character in A
; If CR, also sends LF. Preserves all registers except flags.
;-------------------------------------------------------------
TB_OUTCH:
        PUSH    PSW
        PUSH    B
        PUSH    H
        CALL    0009H           ; PUTCHAR via jump table
        POP     H
        POP     B
        POP     PSW
        CPI     CR
        RNZ
        MVI     A,LF            ; Auto LF after CR
        PUSH    B
        PUSH    H
        CALL    0009H
        POP     H
        POP     B
        MVI     A,CR            ; Restore CR in A
        RET

;-------------------------------------------------------------
; TB_CHKIO - Check for input, handle Ctrl-C
; Returns: Z if no input, NZ with char in A if input available
;-------------------------------------------------------------
TB_CHKIO:
        CALL    0003H           ; CONST via jump table
        RZ                      ; No input available
        CALL    0006H           ; GETCHAR via jump table
        ANI     7FH             ; Strip parity
        CPI     03H             ; Ctrl-C?
        RNZ                     ; No, return char with NZ
        JMP     TB_INIT         ; Yes, restart BASIC

;-------------------------------------------------------------
; TB_GETLN - Read input line into TB_BUFFER
; Input: A = prompt character
; Output: DE -> end-of-line marker (FF)
;-------------------------------------------------------------
TB_GETLN:
        LXI     D,TB_BUFFER
GL1:    CALL    TB_OUTCH        ; Print prompt or echo
GL2:    CALL    TB_CHKIO        ; Get a character
        JZ      GL2             ; Wait for input
        CPI     LF              ; Ignore LF
        JZ      GL2
GL3:    STAX    D               ; Save character
        CPI     08H             ; Backspace?
        JNZ     GL4             ; No, more tests
        ; Backspace: check if at start of buffer
        PUSH    H
        LXI     H,TB_BUFFER
        MOV     A,E
        CMP     L
        JNZ     GLBS1
        MOV     A,D
        CMP     H
        JNZ     GLBS1
        ; At start, nothing to delete
        POP     H
        JMP     GL2
GLBS1:  POP     H
        LDAX    D               ; Get deleted char for echo
        DCX     D
        JMP     GL1             ; Echo backspace
GL4:    CPI     CR              ; CR = end of line?
        JZ      GL5             ; Yes
        ; Check if buffer full
        PUSH    H
        LXI     H,TB_BUFEND
        MOV     A,E
        CMP     L
        JNZ     GLNF
        MOV     A,D
        CMP     H
GLNF:   POP     H
        JZ      GL2             ; Buffer full, only accept BS/CR
        LDAX    D               ; Get char for echo
        INX     D               ; Advance buffer pointer
        JMP     GL1             ; Echo and continue
GL5:    INX     D               ; End of line
        INX     D
        MVI     A,0FFH          ; Put FF marker after line
        STAX    D
        DCX     D
        JMP     TB_CRLF         ; Print CR/LF and return

;*************************************************************
;
; *** INITIALIZE ***
;
;*************************************************************

TB_INIT:
        LXI     SP,TB_STACK
        CALL    TB_CRLF
        LXI     H,TB_KEYWRD     ; Check cold-start flag
        MVI     A,0C3H          ; Magic value (JMP opcode)
        CMP     M
        JZ      TB_TELL         ; Already initialized
        MOV     M,A             ; Set flag
        ; Set default text limit
        LXI     H,TB_STACK+2048 ; Default: 2KB of text space
        SHLD    TB_TXTLMT
        ; Initialize random pointer
        MVI     A,TB_INIT SHR 8
        STA     TB_RANPNT+1
TB_PURGE:
        LXI     H,TB_TEXT+4     ; Purge text area
        SHLD    TB_TXTUNF
        MVI     H,0FFH
        SHLD    TB_TEXT
TB_TELL:
        LXI     D,TB_MSG        ; Print banner
        CALL    TB_PRTSTG
        JMP     TB_RSTART

TB_MSG: DB      'TINY BASIC V3.0',CR
TB_OK:  DB      'OK',CR
TB_WHAT:
        DB      'WHAT?',CR
TB_HOW: DB      'HOW?',CR
TB_SORRY:
        DB      'SORRY',CR

;*************************************************************
;
; *** DIRECT COMMAND / TEXT COLLECTOR ***
;
;*************************************************************

TB_RSTART:
        LXI     SP,TB_STACK     ; Re-initialize stack
        LXI     H,ST1+1         ; Literal 0
        SHLD    TB_CURRNT       ; CURRNT -> line # = 0
ST1:    LXI     H,0
        SHLD    TB_LOPVAR
        SHLD    TB_STKGOS
        LXI     D,TB_OK
        CALL    TB_PRTSTG       ; Print "OK"
ST2:    MVI     A,'>'           ; Prompt
        CALL    TB_GETLN        ; Read a line
        PUSH    D               ; DE -> end of line
        LXI     D,TB_BUFFER     ; DE -> beginning of line
        CALL    TB_TSTNUM       ; Test if it is a number
        CALL    TB_IGNBLK
        MOV     A,H             ; HL = value of # or 0
        ORA     L
        POP     B               ; BC -> end of line
        JZ      TB_DIRECT
        DCX     D               ; Backup DE and save
        MOV     A,H             ; value of line # there
        STAX    D
        DCX     D
        MOV     A,L
        STAX    D
        PUSH    B               ; BC,DE -> begin, end
        PUSH    D
        MOV     A,C
        SUB     E
        PUSH    PSW             ; A = # of bytes in line
        CALL    TB_FNDLN        ; Find this line in save area
        PUSH    D               ; DE -> save area
        JNZ     ST3             ; NZ: not found, insert
        PUSH    D               ; Z: found, delete it
        CALL    TB_FNDNXT       ; Set DE -> next line
        POP     B               ; BC -> line to be deleted
        LHLD    TB_TXTUNF       ; HL -> unfilled save area
        CALL    TB_MVUP         ; Move up to delete
        MOV     H,B             ; TXTUNF -> unfilled area
        MOV     L,C
        SHLD    TB_TXTUNF       ; Update
ST3:    POP     B               ; Get ready to insert
        LHLD    TB_TXTUNF       ; But first check if
        POP     PSW             ; the length of new line
        PUSH    H               ; is 3 (line # and CR)
        CPI     3               ; then do not insert
        JZ      TB_RSTART       ; Must clear the stack
        ADD     L               ; Compute new TXTUNF
        MOV     E,A
        MVI     A,0
        ADC     H
        MOV     D,A             ; DE -> new unfilled area
        LHLD    TB_TXTLMT       ; Check if there is
        XCHG
        CALL    TB_COMP         ; enough space
        JNC     TB_QSORRY       ; Sorry, no room
        SHLD    TB_TXTUNF       ; OK, update TXTUNF
        POP     D               ; DE -> old unfilled area
        CALL    TB_MVDOWN
        POP     D               ; DE -> begin, HL -> end
        POP     H
        CALL    TB_MVUP         ; Move new line to save area
        JMP     ST2

;*************************************************************
;
; *** DIRECT *** & EXEC ***
;
;*************************************************************

TB_DIRECT:
        LXI     H,TAB1-1        ; Direct commands table

TB_EXEC:
        CALL    TB_IGNBLK        ; Ignore leading blanks
        PUSH    D               ; Save pointer
EX1:    LDAX    D               ; If found '.' in string
        INX     D               ; before any mismatch
        CPI     '.'             ; we declare a match
        JZ      EX3
        INX     H               ; HL -> table
        CMP     M               ; If match, test next
        JZ      EX1
        MVI     A,07FH          ; Else, see if bit 7
        DCX     D               ; of table is set
        CMP     M               ; which is the jump addr (hi)
        JC      EX5             ; C: yes, matched
EX2:    INX     H               ; NC: no, find jump addr
        CMP     M
        JNC     EX2
        INX     H               ; Bump to next table item
        POP     D               ; Restore string pointer
        JMP     TB_EXEC         ; Test against next item
EX3:    MVI     A,07FH          ; Partial match, find
EX4:    INX     H               ; jump addr, which is
        CMP     M               ; flagged by bit 7
        JNC     EX4
EX5:    MOV     A,M             ; Load HL with the jump
        INX     H               ; address from the table
        MOV     L,M
        ANI     07FH            ; Mask off bit 7
        MOV     H,A
        POP     PSW             ; Clean up the garbage
        PCHL                    ; And we go do it

;*************************************************************
;
; *** NEW *** STOP *** RUN *** & GOTO ***
;
;*************************************************************

TB_NEW:
        CALL    TB_ENDCHK
        JMP     TB_PURGE

TB_STOP:
        CALL    TB_ENDCHK
        JMP     TB_RSTART

TB_RUN:
        CALL    TB_ENDCHK
        LXI     D,TB_TEXT       ; First saved line

TB_RUNNXL:
        LXI     H,0
        CALL    TB_FNDLP        ; Find whatever line #
        JC      TB_RSTART       ; C: passed TXTUNF, quit

TB_RUNTSL:
        XCHG
        SHLD    TB_CURRNT       ; Set CURRNT -> line #
        XCHG
        INX     D               ; Bump past line #
        INX     D

TB_RUNSML:
        CALL    TB_CHKIO        ; Check for Ctrl-C
        LXI     H,TAB2-1        ; Find command in TAB2
        JMP     TB_EXEC         ; And execute it

TB_GOTO:
        CALL    TB_EXPR         ; Evaluate expression
        PUSH    D               ; Save for error routine
        CALL    TB_ENDCHK       ; Must find a CR
        CALL    TB_FNDLN        ; Find the target line
        JNZ     TB_AHOW         ; No such line #
        POP     PSW             ; Clear the "PUSH DE"
        JMP     TB_RUNTSL       ; Go do it

;*************************************************************
;
; *** LIST *** & PRINT ***
;
;*************************************************************

TB_LIST:
        CALL    TB_TSTNUM       ; Test if there is a #
        PUSH    H
        LXI     H,0FFFFH
        CALL    TB_TSTCH        ; TSTC ','
        DB      ','
        DB      LS1-$-1
        CALL    TB_TSTNUM
LS1:    XTHL
        CALL    TB_ENDCHK       ; If no # we get a 0
        CALL    TB_FNDLN        ; Find this or next line
LS2:    JC      TB_RSTART       ; C: passed TXTUNF
        XTHL
        MOV     A,H
        ORA     L
        JZ      TB_RSTART
        DCX     H
        XTHL
        CALL    TB_PRTLN        ; Print the line
        CALL    TB_PRTSTG
        CALL    TB_CHKIO
        CALL    TB_FNDLP        ; Find next line
        JMP     LS2

TB_PRINT:
        MVI     C,8             ; C = # of spaces
        CALL    TB_TSTCH        ; TSTC ';'
        DB      ';'
        DB      PR1-$-1
        CALL    TB_CRLF         ; Null list & ";"
        JMP     TB_RUNSML       ; Continue same line
PR1:    CALL    TB_TSTCH        ; TSTC CR
        DB      CR
        DB      PR6-$-1
        CALL    TB_CRLF         ; Null list (CR)
        JMP     TB_RUNNXL       ; Go to next line
PR2:    CALL    TB_TSTCH        ; TSTC '#'
        DB      '#'
        DB      PR3A-$-1
PR3:    CALL    TB_EXPR         ; Evaluate format expr
        MVI     A,0C0H
        ANA     L
        ORA     H
        JNZ     TB_QHOW
        MOV     C,L             ; Save format in C
        JMP     PR5             ; Look for more to print
PR3A:   CALL    TB_QTSTG        ; Or is it a string?
        JMP     PR9             ; If not, must be expr
PR5:    CALL    TB_TSTCH        ; TSTC ','
        DB      ','
        DB      PR8-$-1
PR6:    CALL    TB_TSTCH        ; TSTC ','
        DB      ','
        DB      PR7-$-1
        MVI     A,' '
        CALL    TB_OUTCH
        JMP     PR6
PR7:    CALL    TB_FIN          ; In the list
        JMP     PR2             ; List continues
PR8:    CALL    TB_CRLF         ; List ends
        JMP     TB_FINISH
PR9:    CALL    TB_EXPR         ; Evaluate the expr
        PUSH    B
        CALL    TB_PRTNUM       ; Print the value
        POP     B
        JMP     PR5             ; More to print?

;*************************************************************
;
; *** GOSUB *** & RETURN ***
;
;*************************************************************

TB_GOSUB:
        CALL    TB_PUSHA        ; Save current FOR parameters
        CALL    TB_EXPR
        PUSH    D               ; Save text pointer
        CALL    TB_FNDLN        ; Find the target line
        JNZ     TB_AHOW         ; Not there. Say "HOW?"
        LHLD    TB_CURRNT       ; Save old CURRNT
        PUSH    H
        LHLD    TB_STKGOS       ; Old STKGOS
        PUSH    H
        LXI     H,0             ; Load new ones
        SHLD    TB_LOPVAR
        DAD     SP
        SHLD    TB_STKGOS
        JMP     TB_RUNTSL       ; Then run that line

TB_RETURN:
        CALL    TB_ENDCHK       ; Must be a CR
        LHLD    TB_STKGOS       ; Old stack pointer
        MOV     A,H             ; 0 means not exist
        ORA     L
        JZ      TB_QWHAT        ; So, we say: "WHAT?"
        SPHL                    ; Else restore it
TB_RESTOR:
        POP     H
        SHLD    TB_STKGOS       ; And the old STKGOS
        POP     H
        SHLD    TB_CURRNT       ; And the old CURRNT
        POP     D               ; Old text pointer
        CALL    TB_POPA         ; Old FOR parameters
        JMP     TB_FINISH

;*************************************************************
;
; *** FOR *** & NEXT ***
;
;*************************************************************

TB_FOR:
        CALL    TB_PUSHA        ; Save the old save area
        CALL    TB_SETVAL       ; Set the control var
        DCX     H               ; HL is its address
        SHLD    TB_LOPVAR       ; Save that
        LXI     H,TAB4-1        ; Use EXEC to look
        JMP     TB_EXEC         ; for the word 'TO'

FR1:    CALL    TB_EXPR         ; Evaluate the limit
        SHLD    TB_LOPLMT       ; Save that
        LXI     H,TAB5-1        ; Use EXEC to look
        JMP     TB_EXEC         ; for the word 'STEP'

FR2:    CALL    TB_EXPR         ; Found it, get step
        JMP     FR4

FR3:    LXI     H,1             ; Not found, set to 1

FR4:    SHLD    TB_LOPINC       ; Save that too
        LHLD    TB_CURRNT       ; Save current line #
        SHLD    TB_LOPLN
        XCHG                    ; And text pointer
        SHLD    TB_LOPPT
        LXI     B,10            ; Dig into stack to
        LHLD    TB_LOPVAR       ; find LOPVAR
        XCHG
        MOV     H,B
        MOV     L,B             ; HL=0 now
        DAD     SP              ; Here is the stack
        JMP     FR6
FR5:    DAD     B               ; Each level is 10 deep
FR6:    MOV     A,M             ; Get that old LOPVAR
        INX     H
        ORA     M
        JZ      FR7             ; 0 says no more in it
        MOV     A,M
        DCX     H
        CMP     D               ; Same as this one?
        JNZ     FR5
        MOV     A,M             ; The other half?
        CMP     E
        JNZ     FR5
        XCHG                    ; Yes, found one
        LXI     H,0
        DAD     SP              ; Try to move SP
        MOV     B,H
        MOV     C,L
        LXI     H,10
        DAD     D
        CALL    TB_MVDOWN       ; And purge 10 words
        SPHL                    ; In the stack
FR7:    LHLD    TB_LOPPT        ; Job done, restore DE
        XCHG
        JMP     TB_FINISH       ; And continue

TB_NEXT:
        CALL    TB_TSTV         ; Get address of var
        JC      TB_QWHAT        ; No variable, "WHAT?"
        SHLD    TB_VARNXT       ; Yes, save it
NX1:    PUSH    D               ; Save text pointer
        XCHG
        LHLD    TB_LOPVAR       ; Get var in FOR
        MOV     A,H
        ORA     L               ; 0 says never had one
        JZ      TB_AWHAT        ; So we ask: "WHAT?"
        CALL    TB_COMP         ; Else we check them
        JZ      NX2             ; OK, they agree
        POP     D               ; No, let's see
        CALL    TB_POPA         ; Purge current loop
        LHLD    TB_VARNXT       ; And pop one level
        JMP     NX1             ; Go check again
NX2:    MOV     E,M             ; Come here when agreed
        INX     H
        MOV     D,M             ; DE = value of var
        LHLD    TB_LOPINC
        PUSH    H
        MOV     A,H
        XRA     D               ; S = sign differ
        MOV     A,D             ; A = sign of DE
        DAD     D               ; Add one step
        JM      NX3             ; Cannot overflow
        XRA     H               ; May overflow
        JM      NX5             ; And it did
NX3:    XCHG
        LHLD    TB_LOPVAR       ; Put it back
        MOV     M,E
        INX     H
        MOV     M,D
        LHLD    TB_LOPLMT       ; HL = limit
        POP     PSW             ; Old HL
        ORA     A
        JP      NX4             ; Step > 0
        XCHG                    ; Step < 0
NX4:    CALL    TB_CKHLDE       ; Compare with limit
        POP     D               ; Restore text pointer
        JC      NX6             ; Outside limit
        LHLD    TB_LOPLN        ; Within limit, go
        SHLD    TB_CURRNT       ; back to the saved
        LHLD    TB_LOPPT        ; CURRNT and text
        XCHG                    ; pointer
        JMP     TB_FINISH
NX5:    POP     H               ; Overflow, purge
        POP     D               ; garbage in stack
NX6:    CALL    TB_POPA         ; Purge this loop
        JMP     TB_FINISH

;*************************************************************
;
; *** REM *** IF *** INPUT *** & LET ***
;
;*************************************************************

TB_REM:
        LXI     H,0             ; REM = IF 0
        JMP     IF1

TB_IFF:
        CALL    TB_EXPR
IF1:    MOV     A,H             ; Is the expr = 0?
        ORA     L
        JNZ     TB_RUNSML       ; No, continue
        CALL    TB_FNDSKP       ; Yes, skip rest of line
        JNC     TB_RUNTSL       ; And run the next line
        JMP     TB_RSTART       ; If no next, re-start

TB_INPERR:
        LHLD    TB_STKINP       ; Restore old SP
        SPHL
        POP     H               ; And old CURRNT
        SHLD    TB_CURRNT
        POP     D               ; And old text pointer
        POP     D               ; Redo input

TB_INPUT:
IP1:    PUSH    D               ; Save in case of error
        CALL    TB_QTSTG        ; Is next item a string?
        JMP     IP8             ; No
IP2:    CALL    TB_TSTV         ; Yes, but followed by var?
        JC      IP5             ; No
IP3:    CALL    IP12
        LXI     D,TB_BUFFER     ; Point to buffer
        CALL    TB_EXPR         ; Evaluate input
        CALL    TB_ENDCHK
        POP     D               ; OK, get old HL
        XCHG
        MOV     M,E             ; Save value in var
        INX     H
        MOV     M,D
IP4:    POP     H               ; Get old CURRNT
        SHLD    TB_CURRNT
        POP     D               ; And old text pointer
IP5:    POP     PSW             ; Purge junk in stack
IP6:    CALL    TB_TSTCH        ; TSTC ','
        DB      ','
        DB      IP7-$-1
        JMP     TB_INPUT        ; Yes, more items
IP7:    JMP     TB_FINISH

IP8:    PUSH    D               ; Save for PRTSTG
        CALL    TB_TSTV         ; Must be variable now
        JNC     IP11
IP10:   JMP     TB_QWHAT        ; "WHAT?" it is not
IP11:   MOV     B,E
        POP     D
        CALL    TB_PRTCHS       ; Print those as prompt
        JMP     IP3             ; Yes, input variable

IP12:   POP     B               ; Return address
        PUSH    D               ; Save text pointer
        XCHG
        LHLD    TB_CURRNT       ; Also save CURRNT
        PUSH    H
        LXI     H,IP1           ; A negative number
        SHLD    TB_CURRNT       ; as a flag
        LXI     H,0             ; Save SP too
        DAD     SP
        SHLD    TB_STKINP
        PUSH    D               ; Old HL
        MVI     A,' '           ; Print a space
        PUSH    B
        JMP     TB_GETLN        ; And get a line

TB_DEFLT:
        LDAX    D               ; Empty line is OK
        CPI     CR
        JZ      LT4             ; Else it is LET

TB_LET:
LT2:    CALL    TB_SETVAL
LT3:    CALL    TB_TSTCH        ; TSTC ','
        DB      ','
        DB      LT4-$-1
        JMP     TB_LET          ; Item by item
LT4:    JMP     TB_FINISH       ; Until finish

;*************************************************************
;
; *** EXPR ***
;
;*************************************************************

TB_EXPR:
        CALL    EXPR1           ; Get first expr1
        PUSH    H               ; Save value
        LXI     H,TAB6-1        ; Lookup rel.op.
        JMP     TB_EXEC         ; Go do it

XPR1:   CALL    XPR8            ; Rel.op. ">="
        RC                      ; No, return HL=0
        MOV     L,A             ; Yes, return HL=1
        RET

XPR2:   CALL    XPR8            ; Rel.op. "#"
        RZ                      ; False, return HL=0
        MOV     L,A             ; True, return HL=1
        RET

XPR3:   CALL    XPR8            ; Rel.op. ">"
        RZ                      ; False
        RC                      ; Also false, HL=0
        MOV     L,A             ; True, HL=1
        RET

XPR4:   CALL    XPR8            ; Rel.op. "<="
        MOV     L,A             ; Set HL=1
        RZ                      ; Rel. true, return
        RC
        MOV     L,H             ; Else set HL=0
        RET

XPR5:   CALL    XPR8            ; Rel.op. "="
        RNZ                     ; False, return HL=0
        MOV     L,A             ; Else set HL=1
        RET

XPR6:   CALL    XPR8            ; Rel.op. "<"
        RNC                     ; False, return HL=0
        MOV     L,A             ; Else set HL=1
        RET

XPR7:   POP     H               ; Not rel.op.
        RET                     ; Return HL = <EXPR1>

XPR8:   MOV     A,C             ; Subroutine for all
        POP     H               ; rel.op.'s
        POP     B
        PUSH    H               ; Reverse top of stack
        PUSH    B
        MOV     C,A
        CALL    EXPR1           ; Get 2nd <EXPR1>
        XCHG                    ; Value in DE now
        XTHL                    ; 1st <EXPR1> in HL
        CALL    TB_CKHLDE       ; Compare 1st with 2nd
        POP     D               ; Restore text pointer
        LXI     H,0             ; Set HL=0, A=1
        MVI     A,1
        RET

EXPR1:  CALL    TB_TSTCH        ; Negative sign?
        DB      '-'
        DB      XP11-$-1
        LXI     H,0             ; Yes, fake "0-"
        JMP     XP16            ; Treat like subtract
XP11:   CALL    TB_TSTCH        ; Positive sign? Ignore
        DB      '+'
        DB      XP12-$-1
XP12:   CALL    EXPR2           ; 1st <EXPR2>
XP13:   CALL    TB_TSTCH        ; Add?
        DB      '+'
        DB      XP15-$-1
        PUSH    H               ; Yes, save value
        CALL    EXPR2           ; Get 2nd <EXPR2>
XP14:   XCHG                    ; 2nd in DE
        XTHL                    ; 1st in HL
        MOV     A,H             ; Compare sign
        XRA     D
        MOV     A,D
        DAD     D
        POP     D               ; Restore text pointer
        JM      XP13            ; Signs differ, no overflow
        XRA     H               ; Signs same, check result
        JP      XP13            ; OK
        JMP     TB_QHOW         ; Overflow
XP15:   CALL    TB_TSTCH        ; Subtract?
        DB      '-'
        DB      XPR9-$-1
XP16:   PUSH    H               ; Yes, save 1st <EXPR2>
        CALL    EXPR2           ; Get 2nd <EXPR2>
        CALL    TB_CHGSGN       ; Negate
        JMP     XP14            ; And add them

EXPR2:  CALL    EXPR3           ; Get 1st <EXPR3>
XP21:   CALL    TB_TSTCH        ; Multiply?
        DB      '*'
        DB      XP24-$-1
        PUSH    H               ; Yes, save 1st
        CALL    EXPR3           ; And get 2nd <EXPR3>
        MVI     B,0             ; Clear B for sign
        CALL    TB_CHKSGN       ; Check sign
        XTHL                    ; 1st in HL
        CALL    TB_CHKSGN       ; Check sign of 1st
        XCHG
        XTHL
        MOV     A,H             ; Is HL > 255?
        ORA     A
        JZ      XP22            ; No
        MOV     A,D             ; Yes, how about DE
        ORA     D
        XCHG                    ; Put smaller in HL
        JNZ     TB_AHOW         ; Also >, will overflow
XP22:   MOV     A,L             ; This is dumb
        LXI     H,0             ; Clear result
        ORA     A               ; Add and count
        JZ      XP25
XP23:   DAD     D
        JC      TB_AHOW         ; Overflow
        DCR     A
        JNZ     XP23
        JMP     XP25            ; Finished
XP24:   CALL    TB_TSTCH        ; Divide?
        DB      '/'
        DB      XPR9-$-1
        PUSH    H               ; Yes, save 1st <EXPR3>
        CALL    EXPR3           ; And get 2nd one
        MVI     B,0             ; Clear B for sign
        CALL    TB_CHKSGN       ; Check sign of 2nd
        XTHL                    ; Get 1st in HL
        CALL    TB_CHKSGN       ; Check sign of 1st
        XCHG
        XTHL
        XCHG
        MOV     A,D             ; Divide by 0?
        ORA     E
        JZ      TB_AHOW         ; Say "HOW?"
        PUSH    B               ; Else save sign
        CALL    TB_DIVIDE       ; Use subroutine
        MOV     H,B             ; Result in HL now
        MOV     L,C
        POP     B               ; Get sign back
XP25:   POP     D               ; And text pointer
        MOV     A,H             ; HL must be +
        ORA     A
        JM      TB_QHOW         ; Else overflow
        MOV     A,B
        ORA     A
        CM      TB_CHGSGN       ; Change sign if needed
        JMP     XP21            ; Look for more terms

EXPR3:  LXI     H,TAB3-1        ; Find function in TAB3
        JMP     TB_EXEC         ; And go do it

TB_NOTF:
        CALL    TB_TSTV         ; No, not a function
        JC      XP32            ; Nor a variable
        MOV     A,M             ; Variable
        INX     H
        MOV     H,M             ; Value in HL
        MOV     L,A
        RET
XP32:   CALL    TB_TSTNUM       ; Or is it a number
        MOV     A,B             ; # of digits
        ORA     A
        RNZ                     ; OK
TB_PARN:
        CALL    TB_TSTCH        ; No digit, must be
        DB      '('
        DB      XPR0-$-1
TB_PARNP:
        CALL    TB_EXPR         ; "(EXPR)"
        CALL    TB_TSTCH
        DB      ')'
        DB      XPR0-$-1
XPR9:   RET
XPR0:   JMP     TB_QWHAT        ; Else say: "WHAT?"

;*************************************************************
;
; *** RND *** ABS *** SIZE ***
;
;*************************************************************

TB_RND:
        CALL    TB_PARN         ; RND(EXPR)
        MOV     A,H             ; Expr must be +
        ORA     A
        JM      TB_QHOW
        ORA     L               ; And non-zero
        JZ      TB_QHOW
        PUSH    D               ; Save both
        PUSH    H
        LHLD    TB_RANPNT       ; Get memory as random
        LXI     D,TB_RANEND
        CALL    TB_COMP
        JC      RA1             ; Wrap around if past end
        LXI     H,TB_INIT
RA1:    MOV     E,M
        INX     H
        MOV     D,M
        SHLD    TB_RANPNT
        POP     H
        XCHG
        PUSH    B
        CALL    TB_DIVIDE       ; RND(N) = MOD(M,N)+1
        POP     B
        POP     D
        INX     H
        RET

TB_ABS:
        CALL    TB_PARN         ; ABS(EXPR)
        DCX     D
        CALL    TB_CHKSGN       ; Check sign
        INX     D
        RET

TB_SIZE:
        LHLD    TB_TXTUNF       ; Get the number of free
        PUSH    D               ; bytes between TXTUNF
        XCHG                    ; and TXTLMT
        LHLD    TB_TXTLMT
        CALL    TB_SUBDE
        POP     D
        RET

;*************************************************************
;
; *** BYE *** - Return to monitor
;
;*************************************************************

TB_BYE:
        JMP     0000H           ; Warm boot via jump table

;*************************************************************
;
; *** DIVIDE *** SUBDE *** CHKSGN *** CHGSGN *** CKHLDE ***
;
;*************************************************************

TB_DIVIDE:
        PUSH    H               ; Divide H by DE
        MOV     L,H
        MVI     H,0
        CALL    DV1
        MOV     B,C             ; Save result in B
        MOV     A,L             ; (remainder+L)/DE
        POP     H
        MOV     H,A
DV1:    MVI     C,-1            ; Result in C
DV2:    INR     C               ; Dumb routine
        CALL    TB_SUBDE        ; Divide by subtract
        JNC     DV2             ; And count
        DAD     D
        RET

TB_SUBDE:
        MOV     A,L             ; Subtract DE from HL
        SUB     E
        MOV     L,A
        MOV     A,H
        SBB     D
        MOV     H,A
        RET

TB_CHKSGN:
        MOV     A,H             ; Check sign of HL
        ORA     A               ; If +, no change
        RP                      ; If -, change sign

TB_CHGSGN:
        MOV     A,H             ; Change sign of HL
        ORA     L
        RZ
        MOV     A,H
        PUSH    PSW
        CMA                     ; Complement HL
        MOV     H,A
        MOV     A,L
        CMA
        MOV     L,A
        INX     H               ; Two's complement
        POP     PSW
        XRA     H
        JP      TB_QHOW         ; Overflow check
        MOV     A,B             ; Also flip B
        XRI     080H
        MOV     B,A
        RET

TB_CKHLDE:
        MOV     A,H
        XRA     D               ; Same sign?
        JP      CK1             ; Yes, compare
        XCHG                    ; No, exchange and compare
CK1:    CALL    TB_COMP
        RET

TB_COMP:
        MOV     A,H             ; Compare HL with DE
        CMP     D               ; Return correct C and
        RNZ                     ; Z flags
        MOV     A,L             ; But old A is lost
        CMP     E
        RET

;*************************************************************
;
; *** SETVAL *** FIN *** ENDCHK *** & ERROR ***
;
;*************************************************************

TB_SETVAL:
        CALL    TB_TSTV         ; Test for variable
        JC      TB_QWHAT        ; "WHAT?" no variable
        PUSH    H               ; Save address of var
        CALL    TB_TSTCH        ; Pass "=" sign
        DB      '='
        DB      SV1-$-1
        CALL    TB_EXPR         ; Evaluate expr
        MOV     B,H             ; Value in BC now
        MOV     C,L
        POP     H               ; Get address
        MOV     M,C             ; Save value
        INX     H
        MOV     M,B
        RET

TB_FINISH:
        CALL    TB_FIN          ; Check end of command
SV1:    JMP     TB_QWHAT        ; Print "WHAT?" if wrong

TB_FIN:
        CALL    TB_TSTCH        ; TSTC ';'
        DB      ';'
        DB      FI1-$-1
        POP     PSW             ; ";", purge ret addr
        JMP     TB_RUNSML       ; Continue same line
FI1:    CALL    TB_TSTCH        ; TSTC CR
        DB      CR
        DB      FI2-$-1
        POP     PSW             ; Yes, purge ret addr
        JMP     TB_RUNNXL       ; Run next line
FI2:    RET                     ; Else return to caller

TB_IGNBLK:
        LDAX    D               ; Ignore blanks
        CPI     ' '             ; in text (where DE->)
        RNZ                     ; and return first non-blank
        INX     D
        JMP     TB_IGNBLK

TB_ENDCHK:
        CALL    TB_IGNBLK       ; End with CR?
        CPI     CR
        RZ                      ; OK, else say: "WHAT?"

TB_QWHAT:
        PUSH    D
TB_AWHAT:
        LXI     D,TB_WHAT
TB_ERROR:
        CALL    TB_CRLF
        CALL    TB_PRTSTG       ; Print error message
        LHLD    TB_CURRNT       ; Get current line #
        PUSH    H
        MOV     A,H             ; Check the value
        INX     H
        ORA     M
        POP     D
        JZ      TB_TELL         ; If zero, just restart
        MOV     A,M             ; If negative,
        ORA     A
        JM      TB_INPERR       ; Redo input
        CALL    TB_PRTLN
        POP     B
        MOV     B,C
        CALL    TB_PRTCHS
        MVI     A,'?'           ; Print a "?"
        CALL    TB_OUTCH
        CALL    TB_PRTSTG       ; Print rest of line
        JMP     TB_TELL         ; Then restart

TB_QSORRY:
        PUSH    D
TB_ASORRY:
        LXI     D,TB_SORRY
        JMP     TB_ERROR

TB_QHOW:
        PUSH    D
TB_AHOW:
        LXI     D,TB_HOW
        JMP     TB_ERROR

;*************************************************************
;
; *** FNDLN (& FRIENDS) ***
;
;*************************************************************

TB_FNDLN:
        MOV     A,H             ; Check sign of HL
        ORA     A
        JM      TB_QHOW         ; It cannot be -
        LXI     D,TB_TEXT       ; Init text pointer

TB_FNDLP:
        INX     D               ; Is it EOT mark?
        LDAX    D
        DCX     D
        ADD     A
        RC                      ; C,NZ: passed end
        LDAX    D               ; We did not, get byte 1
        SUB     L               ; Is this the line?
        MOV     B,A             ; Compare low order
        INX     D
        LDAX    D               ; Get byte 2
        SBB     H               ; Compare high order
        JC      FL1             ; No, not there yet
        DCX     D               ; Else we either found
        ORA     B               ; it, or it is not there
        RET                     ; NC,Z:found; NC,NZ:no

TB_FNDNXT:
        INX     D               ; Find next line
FL1:    INX     D               ; Just passed byte 1 & 2

TB_FNDSKP:
        LDAX    D               ; Try to find CR
        CPI     CR
        JNZ     FL1             ; Keep looking
        INX     D               ; Found CR, skip over
        JMP     TB_FNDLP        ; Check if end of text

TB_TSTV:
        CALL    TB_IGNBLK       ; Test variables
        SUI     '@'
        RC                      ; C: not a variable
        JNZ     TV1             ; Not "@" array
        INX     D               ; It is the "@" array
        CALL    TB_PARN         ; @ should be followed
        DAD     H               ; by (EXPR) as its index
        JC      TB_QHOW         ; Is index too big?
TSTB:   PUSH    D               ; Will it fit?
        XCHG
        CALL    TB_SIZE         ; Find size of free
        CALL    TB_COMP         ; and check that
        JC      TB_ASORRY       ; If not, say "SORRY"
        CALL    TB_LOCR         ; If fits, get address
        DAD     D               ; of @(EXPR) and put it
        POP     D               ; in HL
        RET                     ; C flag is cleared
TV1:    CPI     27              ; Not @, is it A to Z?
        CMC                     ; If not return C flag
        RC
        INX     D               ; If A through Z
        LXI     H,TB_VARBGN-2
        RLC                     ; HL -> variable
        ADD     L               ; Return
        MOV     L,A             ; With C flag cleared
        MVI     A,0
        ADC     H
        MOV     H,A
        RET

;*************************************************************
;
; *** TSTCH *** TSTNUM ***
;
;*************************************************************

TB_TSTCH:
        XTHL                    ; Get return addr -> char
        CALL    TB_IGNBLK       ; Ignore leading blanks
        CMP     M               ; Compare the byte that
        INX     H               ; follows the CALL inst.
        JZ      TC1             ; with the text (DE->)
        PUSH    B               ; If not =, add the 2nd
        MOV     C,M             ; byte (relative offset)
        MVI     B,0             ; to the old PC
        DAD     B
        POP     B               ; Do a relative jump
        DCX     D               ; if not equal
TC1:    INX     D               ; If =, skip those bytes
        INX     H               ; and continue
        XTHL
        RET

TB_TSTNUM:
        LXI     H,0             ; Test if text is a number
        MOV     B,H             ; B = 0
        CALL    TB_IGNBLK
TN1:    CPI     '0'             ; If not, return 0 in
        RC                      ; B and HL
        CPI     03AH            ; If numbers, convert
        RNC                     ; to binary in HL
        MVI     A,0F0H          ; Set B to # of digits
        ANA     H               ; If H>255, there is no
        JNZ     TB_QHOW         ; room for next digit
        INR     B               ; B counts # of digits
        PUSH    B
        MOV     B,H             ; HL=10*HL+(new digit)
        MOV     C,L
        DAD     H               ; Where 10* is done by
        DAD     H               ; shift and add
        DAD     B
        DAD     H
        LDAX    D               ; And (digit) is from
        INX     D               ; stripping the ASCII
        ANI     0FH             ; code
        ADD     L
        MOV     L,A
        MVI     A,0
        ADC     H
        MOV     H,A
        POP     B
        LDAX    D               ; Do this digit after
        JP      TN1             ; digit. S says overflow

;*************************************************************
;
; *** MVUP *** MVDOWN *** POPA *** & PUSHA ***
;
;*************************************************************

TB_MVUP:
        CALL    TB_COMP         ; DE = HL, return
        RZ
        LDAX    D               ; Get one byte
        STAX    B               ; Move it
        INX     D               ; Increase both pointers
        INX     B
        JMP     TB_MVUP         ; Until done

TB_MVDOWN:
        MOV     A,B             ; Test if DE = BC
        SUB     D
        JNZ     MD1             ; No, go move
        MOV     A,C             ; Maybe, other byte?
        SUB     E
        RZ                      ; Yes, return
MD1:    DCX     D               ; Else move a byte
        DCX     H               ; But first decrease
        LDAX    D               ; both pointers and
        MOV     M,A             ; then do it
        JMP     TB_MVDOWN       ; Loop back

TB_POPA:
        POP     B               ; BC = return addr
        POP     H               ; Restore LOPVAR, but
        SHLD    TB_LOPVAR       ; =0 means no more
        MOV     A,H
        ORA     L
        JZ      PP1             ; Yes, go return
        POP     H               ; No, restore others
        SHLD    TB_LOPINC
        POP     H
        SHLD    TB_LOPLMT
        POP     H
        SHLD    TB_LOPLN
        POP     H
        SHLD    TB_LOPPT
PP1:    PUSH    B               ; BC = return addr
        RET

TB_PUSHA:
        LXI     H,TB_STKLMT    ; Stack near top?
        CALL    TB_CHGSGN
        POP     B               ; BC = return address
        DAD     SP              ; Is stack near the top?
        JNC     TB_QSORRY       ; Yes, sorry
        LHLD    TB_LOPVAR       ; Else save loop vars
        MOV     A,H             ; But if LOPVAR is 0
        ORA     L               ; that will be all
        JZ      PU1
        LHLD    TB_LOPPT        ; Else, more to save
        PUSH    H
        LHLD    TB_LOPLN
        PUSH    H
        LHLD    TB_LOPLMT
        PUSH    H
        LHLD    TB_LOPINC
        PUSH    H
        LHLD    TB_LOPVAR
PU1:    PUSH    H
        PUSH    B               ; BC = return addr
        RET

TB_LOCR:
        LHLD    TB_TXTUNF
        DCX     H
        DCX     H
        RET

;*************************************************************
;
; *** PRTSTG *** QTSTG *** PRTNUM *** & PRTLN ***
;
;*************************************************************

TB_PRTSTG:
        SUB     A               ; A = 0
PS1:    MOV     B,A
PS2:    LDAX    D               ; Get a character
        INX     D               ; Bump pointer
        CMP     B               ; Same as old A?
        RZ                      ; Yes, return
        CALL    TB_OUTCH        ; Else print it
        CPI     CR              ; Was it a CR?
        JNZ     PS2             ; No, next
        RET                     ; Yes, return

TB_QTSTG:
        CALL    TB_TSTCH        ; TSTC '"'
        DB      '"'
        DB      QT3-$-1
        MVI     A,'"'           ; It is a "
QT1:    CALL    PS1             ; Print until another
QT2:    CPI     CR              ; Was last one a CR?
        POP     H               ; Return address
        JZ      TB_RUNNXL       ; Was CR, run next line
        INX     H               ; Skip 3 bytes on return
        INX     H
        INX     H
        PCHL                    ; Return
QT3:    CALL    TB_TSTCH        ; TSTC single quote
        DB      027H
        DB      QT4-$-1
        MVI     A,027H          ; Yes, do same
        JMP     QT1             ; as in "
QT4:    CALL    TB_TSTCH        ; TSTC up-arrow (^)
        DB      05EH
        DB      QT5-$-1
        LDAX    D               ; Yes, convert character
        XRI     040H            ; to control-ch
        CALL    TB_OUTCH
        LDAX    D               ; Just in case it is a CR
        INX     D
        JMP     QT2
QT5:    RET                     ; None of above

TB_PRTCHS:
        MOV     A,E
        CMP     B
        RZ
        LDAX    D
        CALL    TB_OUTCH
        INX     D
        JMP     TB_PRTCHS

TB_PRTNUM:
        MVI     B,0             ; B = sign
        CALL    TB_CHKSGN       ; Check sign
        JP      PN4             ; No sign
        MVI     B,'-'           ; B = sign
        DCR     C               ; '-' takes space
PN4:    PUSH    D
        LXI     D,10            ; Decimal
        PUSH    D               ; Save as a flag
        DCR     C               ; C = spaces
        PUSH    B               ; Save sign & space
PN5:    CALL    TB_DIVIDE       ; Divide HL by 10
        MOV     A,B             ; Result 0?
        ORA     C
        JZ      PN6             ; Yes, we got all
        XTHL                    ; No, save remainder
        DCR     L               ; and count space
        PUSH    H               ; HL is old BC
        MOV     H,B             ; Move result to HL
        MOV     L,C
        JMP     PN5             ; And divide by 10
PN6:    POP     B               ; We got all digits in
PN7:    DCR     C               ; the stack
        MOV     A,C             ; Look at space count
        ORA     A
        JM      PN8             ; No leading blanks
        MVI     A,' '           ; Leading blanks
        CALL    TB_OUTCH
        JMP     PN7             ; More?
PN8:    MOV     A,B             ; Print sign
        ORA     A
        CNZ     TB_OUTCH        ; Maybe - or null
        MOV     E,L             ; Last remainder in E
PN9:    MOV     A,E             ; Check digit in E
        CPI     10              ; 10 is flag for no more
        POP     D
        RZ                      ; If so, return
        ADI     '0'             ; Else convert to ASCII
        CALL    TB_OUTCH        ; And print the digit
        JMP     PN9             ; Go back for more

TB_PRTLN:
        LDAX    D               ; Low order line #
        MOV     L,A
        INX     D
        LDAX    D               ; High order
        MOV     H,A
        INX     D
        MVI     C,4             ; Print 4 digit line #
        CALL    TB_PRTNUM
        MVI     A,' '           ; Followed by a blank
        CALL    TB_OUTCH
        RET

;*************************************************************
;
; *** COMMAND TABLES ***
;
;*************************************************************

TAB1:                           ; Direct commands
        DB      'LIST'
        DWA     TB_LIST
        DB      'NEW'
        DWA     TB_NEW
        DB      'RUN'
        DWA     TB_RUN
        DB      'BYE'
        DWA     TB_BYE

TAB2:                           ; Direct/statement commands
        DB      'NEXT'
        DWA     TB_NEXT
        DB      'LET'
        DWA     TB_LET
        DB      'IF'
        DWA     TB_IFF
        DB      'GOTO'
        DWA     TB_GOTO
        DB      'GOSUB'
        DWA     TB_GOSUB
        DB      'RETURN'
        DWA     TB_RETURN
        DB      'REM'
        DWA     TB_REM
        DB      'FOR'
        DWA     TB_FOR
        DB      'INPUT'
        DWA     TB_INPUT
        DB      'PRINT'
        DWA     TB_PRINT
        DB      'STOP'
        DWA     TB_STOP
        DWA     TB_MOREC

TB_MOREC:
        JMP     TB_DEFLT        ; Default: try as LET

TAB3:                           ; Functions
        DB      'RND'
        DWA     TB_RND
        DB      'ABS'
        DWA     TB_ABS
        DB      'SIZE'
        DWA     TB_SIZE
        DWA     TB_MOREF

TB_MOREF:
        JMP     TB_NOTF         ; Default: not a function

TAB4:                           ; "TO" in FOR command
        DB      'TO'
        DWA     FR1
        DWA     TB_QWHAT

TAB5:                           ; "STEP" in FOR command
        DB      'STEP'
        DWA     FR2
        DWA     FR3

TAB6:                           ; Relation operators
        DB      '>='
        DWA     XPR1
        DB      '#'
        DWA     XPR2
        DB      '>'
        DWA     XPR3
        DB      '='
        DWA     XPR5
        DB      '<='
        DWA     XPR4
        DB      '<'
        DWA     XPR6
        DWA     XPR7

TB_RANEND       EQU     $       ; End of code, used by RND

        ENDIF                   ; ENABLE_BASIC

;*************************************************************
; End of tinybasic.asm
;*************************************************************
