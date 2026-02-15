;========================================================
; JX Monitor - Command Processor
;========================================================
; Interactive monitor with hex dump, memory test, write,
; execute, memory info, and help commands.
;
; Commands:
;   help / ?           Show available commands
;   dump / d <addr>    Hex dump memory (16 bytes/line)
;   test / t [s e]     Destructive RAM test
;   write / w <a> <b>  Write bytes to memory
;   go / g <addr>      Execute code at address
;   mem / m            Show memory layout
;   cls                Clear screen
;
; This module is INCLUDEd by bios.asm.
;========================================================

;========================================================
; Constants
;========================================================
CMDBUF_SIZE     EQU     64      ; Command buffer size
DUMP_LINES      EQU     8       ; Default lines to dump

;========================================================
; MONITOR - Main monitor entry point
;========================================================
MONITOR:
        LXI     SP,STACK_TOP    ; Reset stack each iteration
        LXI     H,MON_PROMPT
        CALL    PRINTS
        CALL    RDLINE

        ; Skip leading spaces
        LXI     H,CMDBUF
        CALL    SKIPSP
        MOV     A,M
        ORA     A
        JZ      MONITOR         ; Empty line

        SHLD    CMDPTR          ; Save command start
        CALL    FINDSP          ; Find end of command word

        ; Null-terminate command, save arg pointer
        MOV     A,M
        ORA     A
        JZ      MDISP
        MVI     M,0
        INX     H
        CALL    SKIPSP
MDISP:
        SHLD    ARGPTR

        ; Uppercase the command
        LHLD    CMDPTR
        CALL    STRTOUPPER

        ; --- Command dispatch ---
        LHLD    CMDPTR
        LXI     D,CMD_HELP
        CALL    STRCMP
        JZ      DO_HELP
        LHLD    CMDPTR
        LXI     D,CMD_QMARK
        CALL    STRCMP
        JZ      DO_HELP

        LHLD    CMDPTR
        LXI     D,CMD_DUMP
        CALL    STRCMP
        JZ      DO_DUMP
        LHLD    CMDPTR
        LXI     D,CMD_D
        CALL    STRCMP
        JZ      DO_DUMP

        LHLD    CMDPTR
        LXI     D,CMD_TEST
        CALL    STRCMP
        JZ      DO_TEST
        LHLD    CMDPTR
        LXI     D,CMD_T
        CALL    STRCMP
        JZ      DO_TEST

        LHLD    CMDPTR
        LXI     D,CMD_WRITE
        CALL    STRCMP
        JZ      DO_WRITE
        LHLD    CMDPTR
        LXI     D,CMD_W
        CALL    STRCMP
        JZ      DO_WRITE

        LHLD    CMDPTR
        LXI     D,CMD_GO
        CALL    STRCMP
        JZ      DO_GO
        LHLD    CMDPTR
        LXI     D,CMD_G
        CALL    STRCMP
        JZ      DO_GO

        LHLD    CMDPTR
        LXI     D,CMD_MEM
        CALL    STRCMP
        JZ      DO_MEM
        LHLD    CMDPTR
        LXI     D,CMD_M
        CALL    STRCMP
        JZ      DO_MEM

        LHLD    CMDPTR
        LXI     D,CMD_CLS
        CALL    STRCMP
        JZ      DO_CLS

        ; Unknown command
        LXI     H,MSG_UNK
        CALL    PRINTS
        LHLD    CMDPTR
        CALL    PRINTS
        CALL    PRCRLF
        JMP     MONITOR

;========================================================
; Command name strings
;========================================================
CMD_HELP:       DB      'HELP',0
CMD_QMARK:      DB      '?',0
CMD_DUMP:       DB      'DUMP',0
CMD_D:          DB      'D',0
CMD_TEST:       DB      'TEST',0
CMD_T:          DB      'T',0
CMD_WRITE:      DB      'WRITE',0
CMD_W:          DB      'W',0
CMD_GO:         DB      'GO',0
CMD_G:          DB      'G',0
CMD_MEM:        DB      'MEM',0
CMD_M:          DB      'M',0
CMD_CLS:        DB      'CLS',0

;========================================================
; DO_HELP
;========================================================
DO_HELP:
        LXI     H,MSG_HELP
        CALL    PRINTS
        JMP     MONITOR

;========================================================
; DO_DUMP - Hex dump memory
;========================================================
; d <addr> [<end>]
;========================================================
DO_DUMP:
        LHLD    ARGPTR
        CALL    PRHX_IN
        JC      DMP_ERR

        ; Align start to 16-byte boundary
        ; PRHX_IN returned: DE = parsed addr, HL = string ptr
        XCHG                    ; HL = start addr, DE = string ptr
        MOV     A,L
        ANI     0F0H
        MOV     L,A
        SHLD    DMP_ADDR
        XCHG                    ; HL = string ptr (for end addr)

        ; Try to parse end address
        CALL    SKIPSP
        MOV     A,M
        ORA     A
        JZ      DMP_DEF

        CALL    PRHX_IN
        JC      DMP_DEF
        XCHG
        SHLD    DMP_END
        JMP     DMP_GO

DMP_DEF:
        ; Default: 8 lines (128 bytes)
        LHLD    DMP_ADDR
        LXI     D,127
        DAD     D
        SHLD    DMP_END

DMP_GO:
        LHLD    DMP_ADDR
DMP_LP:
        CALL    DMPLINE
        LXI     D,16
        DAD     D
        JC      DMP_FIN         ; Address wrapped past FFFFH
        SHLD    DMP_ADDR

        ; Compare current > end?
        XCHG                    ; DE = next addr
        LHLD    DMP_END         ; HL = end
        MOV     A,D
        CMP     H
        JC      DMP_NXT         ; next_H < end_H -> continue
        JNZ     DMP_FIN         ; next_H > end_H -> done
        MOV     A,E
        CMP     L
        JC      DMP_NXT         ; next_L < end_L -> continue
        JZ      DMP_NXT         ; next_L == end_L -> do one more
        JMP     DMP_FIN         ; next_L > end_L -> done
DMP_NXT:
        LHLD    DMP_ADDR
        JMP     DMP_LP
DMP_FIN:
        JMP     MONITOR

DMP_ERR:
        LXI     H,MSG_DERR
        CALL    PRINTS
        JMP     MONITOR

;========================================================
; DMPLINE - Dump one line of 16 hex bytes + ASCII
;========================================================
; Input: HL = start address
; Output: HL preserved
;========================================================
DMPLINE:
        PUSH    H

        ; Print address
        CALL    PRHEX16
        MVI     A,':'
        CALL    PUTCHAR
        MVI     A,' '
        CALL    PUTCHAR

        ; Hex bytes
        MVI     B,16
        PUSH    H               ; Save for ASCII pass
DMPH1:
        MOV     A,M
        CALL    PRHEX8
        MVI     A,' '
        CALL    PUTCHAR
        ; Extra space after byte 8
        MOV     A,B
        CPI     9
        JNZ     DMPH2
        MVI     A,' '
        CALL    PUTCHAR
DMPH2:
        INX     H
        DCR     B
        JNZ     DMPH1

        ; ASCII sidebar
        MVI     A,' '
        CALL    PUTCHAR
        POP     H               ; Restore for ASCII
        MVI     B,16
DMPA1:
        MOV     A,M
        CPI     20H
        JC      DMPDOT
        CPI     7FH
        JNC     DMPDOT
        JMP     DMPCH
DMPDOT:
        MVI     A,'.'
DMPCH:
        CALL    PUTCHAR
        INX     H
        DCR     B
        JNZ     DMPA1

        CALL    PRCRLF
        POP     H
        RET

;========================================================
; DO_TEST - Destructive RAM test
;========================================================
; t [<start> <end>]
;========================================================
DO_TEST:
        LHLD    ARGPTR
        MOV     A,M
        ORA     A
        JZ      TST_DEF

        CALL    PRHX_IN
        JC      TST_ERR
        XCHG
        SHLD    TST_SADR

        CALL    SKIPSP
        CALL    PRHX_IN
        JC      TST_ERR
        XCHG
        SHLD    TST_EADR
        JMP     TST_RUN

TST_DEF:
        IF BIOS_BASE
        ; Traditional: test free RAM below monitor
        LXI     H,0100H
        SHLD    TST_SADR
        LXI     H,BIOS_BASE-1
        SHLD    TST_EADR
        ELSE
        ; Load-at-zero: test free RAM above monitor
        LXI     H,CODE_END
        SHLD    TST_SADR
        LXI     H,STACK_TOP-1
        SHLD    TST_EADR
        ENDIF

TST_RUN:
        LXI     H,MSG_TSRT
        CALL    PRINTS
        LHLD    TST_SADR
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        LHLD    TST_EADR
        CALL    PRHEX16
        CALL    PRCRLF

        LXI     H,0
        SHLD    TST_ECNT

        LHLD    TST_SADR
TST_LP:
        SHLD    TST_CADR

        MOV     A,M             ; Read original
        MOV     D,A             ; Save
        CMA                     ; Complement
        MOV     M,A             ; Write
        CMP     M               ; Verify
        JZ      TST_OK

        ; Error
        PUSH    H
        PUSH    D
        LHLD    TST_ECNT
        INX     H
        SHLD    TST_ECNT
        LXI     H,MSG_TFER
        CALL    PRINTS
        LHLD    TST_CADR
        CALL    PRHEX16
        CALL    PRCRLF
        POP     D
        POP     H

TST_OK:
        MOV     M,D             ; Restore original

        ; Progress dot every 4KB
        MOV     A,L
        ORA     A
        JNZ     TST_CHK
        MOV     A,H
        ANI     0FH
        JNZ     TST_CHK
        MVI     A,'.'
        CALL    PUTCHAR

TST_CHK:
        ; Check if done
        LHLD    TST_EADR
        XCHG                    ; DE = end
        LHLD    TST_CADR        ; HL = current
        MOV     A,H
        CMP     D
        JC      TST_NXT         ; H < D, continue
        JNZ     TST_FIN         ; H > D, done
        MOV     A,L
        CMP     E
        JC      TST_NXT         ; L < E, continue
        JMP     TST_FIN         ; L >= E, done

TST_NXT:
        LHLD    TST_CADR
        INX     H
        JMP     TST_LP

TST_FIN:
        CALL    PRCRLF
        LXI     H,MSG_TDNE
        CALL    PRINTS
        LHLD    TST_ECNT
        MOV     A,H
        ORA     L
        JNZ     TST_PE

        LXI     H,MSG_TNOE
        CALL    PRINTS
        JMP     MONITOR

TST_PE:
        LHLD    TST_ECNT
        CALL    PRDEC16
        LXI     H,MSG_TERP
        CALL    PRINTS
        JMP     MONITOR

TST_ERR:
        LXI     H,MSG_TERR
        CALL    PRINTS
        JMP     MONITOR

;========================================================
; DO_WRITE - Write bytes to memory
;========================================================
; w <addr> <byte> [<byte>...]
;========================================================
DO_WRITE:
        LHLD    ARGPTR
        CALL    PRHX_IN
        JC      WRT_ERR
        XCHG
        SHLD    WRT_ADDR

WRT_LP:
        CALL    SKIPSP
        MOV     A,M
        ORA     A
        JZ      WRT_OK
        CALL    PRHX_IN
        JC      WRT_OK
        MOV     A,E             ; Low byte of parsed value
        PUSH    H               ; Save parse position
        LHLD    WRT_ADDR
        MOV     M,A
        INX     H
        SHLD    WRT_ADDR
        POP     H
        JMP     WRT_LP

WRT_OK:
        JMP     MONITOR

WRT_ERR:
        LXI     H,MSG_WERR
        CALL    PRINTS
        JMP     MONITOR

;========================================================
; DO_GO - Execute code at address
;========================================================
; g <addr>
; Page zero JMP 0000H returns to monitor.
;========================================================
DO_GO:
        LHLD    ARGPTR
        CALL    PRHX_IN
        JC      GO_ERR
        XCHG                    ; HL = target address
        PCHL                    ; Jump to user code

GO_ERR:
        LXI     H,MSG_GERR
        CALL    PRINTS
        JMP     MONITOR

;========================================================
; DO_MEM - Show memory layout
;========================================================
DO_MEM:
        LXI     H,MSG_MLYT
        CALL    PRINTS

        LXI     H,MSG_MTOT
        CALL    PRINTS
        LHLD    DETECTED_MEM
        MOV     A,H
        ORA     A
        JNZ     MEM_KB
        MVI     A,64
        JMP     MEM_KP
MEM_KB:
        RRC
        RRC
        ANI     03FH
MEM_KP:
        CALL    PRDEC8
        LXI     H,MSG_MKB
        CALL    PRINTS

        ; Free RAM range (computed from layout)
        LXI     H,MSG_MFRL
        CALL    PRINTS
        IF BIOS_BASE
        LXI     H,0100H
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        LXI     H,BIOS_BASE-1
        CALL    PRHEX16
        ELSE
        LXI     H,CODE_END
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        LXI     H,MEMTOP-1
        CALL    PRHEX16
        ENDIF
        LXI     H,MSG_MFRR
        CALL    PRINTS

        IF VIDEO_BASE
        LXI     H,MSG_MVDL
        CALL    PRINTS
        LXI     H,VIDEO_BASE
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        LXI     H,VIDEO_BASE+VIDEO_SIZE-1
        CALL    PRHEX16
        LXI     H,MSG_MVDR
        CALL    PRINTS
        ENDIF

        ; Monitor range
        LXI     H,MSG_MMNL
        CALL    PRINTS
        LXI     H,BIOS_BASE
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        LXI     H,CODE_END-1
        CALL    PRHEX16
        CALL    PRCRLF

        JMP     MONITOR

;========================================================
; DO_CLS - Clear screen
;========================================================
DO_CLS:
        ; ANSI escape: clear screen + home cursor
        MVI     A,1BH
        CALL    PUTCHAR
        MVI     A,'['
        CALL    PUTCHAR
        MVI     A,'2'
        CALL    PUTCHAR
        MVI     A,'J'
        CALL    PUTCHAR
        MVI     A,1BH
        CALL    PUTCHAR
        MVI     A,'['
        CALL    PUTCHAR
        MVI     A,'H'
        CALL    PUTCHAR
        IF VIDEO_BASE
        CALL    V_CLEAR
        XRA     A
        STA     V_CURROW
        STA     V_CURCOL
        ENDIF
        JMP     MONITOR

;========================================================
; RDLINE - Read line into CMDBUF
;========================================================
; Handles: CR (done), BS/DEL (backspace), printable chars.
; Null-terminates buffer. Echoes characters.
; Destroys: A, B, C, H, L
;========================================================
RDLINE:
        LXI     H,CMDBUF
        MVI     B,0             ; Count
RDLLP:
        CALL    GETCHAR
        MOV     C,A             ; Save char in C

        ; CR = done
        CPI     0DH
        JZ      RDLDN

        ; Ignore LF
        CPI     0AH
        JZ      RDLLP

        ; BS or DEL = backspace
        CPI     08H
        JZ      RDLBS
        CPI     7FH
        JZ      RDLBS

        ; Ignore non-printable
        CPI     20H
        JC      RDLLP

        ; Buffer full?
        MOV     A,B
        CPI     CMDBUF_SIZE-1
        JNC     RDLLP

        ; Store and echo
        MOV     M,C             ; Store character
        INX     H
        INR     B
        MOV     A,C
        CALL    PUTCHAR
        JMP     RDLLP

RDLBS:
        MOV     A,B
        ORA     A
        JZ      RDLLP           ; Nothing to delete
        DCR     B
        DCX     H
        MVI     A,08H
        CALL    PUTCHAR
        MVI     A,' '
        CALL    PUTCHAR
        MVI     A,08H
        CALL    PUTCHAR
        JMP     RDLLP

RDLDN:
        MVI     M,0             ; Null terminate
        CALL    PRCRLF
        RET

;========================================================
; PRHX_IN - Parse hex number from input string
;========================================================
; Input:  HL = pointer to string (updated past number)
; Output: DE = parsed value, HL = updated pointer
;         Carry set if no valid hex digits found
; Destroys: A, D, E
;========================================================
PRHX_IN:
        CALL    SKIPSP
        LXI     D,0             ; Result = 0
        MVI     C,0             ; Digit count

PHXLP:
        MOV     A,M
        ; Check 0-9
        CPI     '0'
        JC      PHXDN
        CPI     '9'+1
        JC      PHXDIG
        ; Check A-F
        CPI     'A'
        JC      PHXDN
        CPI     'F'+1
        JC      PHXAF
        ; Check a-f
        CPI     'a'
        JC      PHXDN
        CPI     'f'+1
        JC      PHXAF2
        JMP     PHXDN

PHXDIG:
        ; Digit 0-9
        SUI     '0'
        JMP     PHXADD

PHXAF:
        ; Letter A-F
        SUI     'A'-10
        JMP     PHXADD

PHXAF2:
        ; Letter a-f
        SUI     'a'-10

PHXADD:
        ; Shift DE left 4 bits and add nibble
        PUSH    PSW             ; Save nibble
        ; DE <<= 4
        MOV     A,D
        RLC
        RLC
        RLC
        RLC
        ANI     0F0H
        MOV     D,A
        MOV     A,E
        RLC
        RLC
        RLC
        RLC
        PUSH    PSW             ; Save shifted E
        ANI     0F0H
        MOV     E,A
        POP     PSW             ; Get shifted E bits
        ANI     0FH             ; High nibble of old E -> low nibble of D
        ORA     D
        MOV     D,A
        POP     PSW             ; Get nibble value
        ORA     E
        MOV     E,A

        INR     C               ; Count digit
        INX     H
        JMP     PHXLP

PHXDN:
        ; Check if we got any digits
        MOV     A,C
        ORA     A
        STC                     ; Set carry (error)
        RZ                      ; No digits -> return with carry
        ORA     A               ; Clear carry (success)
        RET

;========================================================
; SKIPSP - Skip spaces in string
;========================================================
; Input:  HL = string pointer
; Output: HL = first non-space character
;========================================================
SKIPSP:
        MOV     A,M
        CPI     ' '
        RNZ
        INX     H
        JMP     SKIPSP

;========================================================
; FINDSP - Find next space or null
;========================================================
; Input:  HL = string pointer
; Output: HL = space or null terminator
;========================================================
FINDSP:
        MOV     A,M
        ORA     A
        RZ                      ; Null = done
        CPI     ' '
        RZ                      ; Space = done
        INX     H
        JMP     FINDSP

;========================================================
; Monitor variables
;========================================================
CMDPTR:         DW      0       ; Pointer to command string
ARGPTR:         DW      0       ; Pointer to arguments
DMP_ADDR:       DW      0       ; Dump current address
DMP_END:        DW      0       ; Dump end address
TST_SADR:       DW      0       ; Test start address
TST_EADR:       DW      0       ; Test end address
TST_CADR:       DW      0       ; Test current address
TST_ECNT:       DW      0       ; Test error count
WRT_ADDR:       DW      0       ; Write current address
CMDBUF:         DS      CMDBUF_SIZE     ; Command input buffer

;========================================================
; Monitor messages
;========================================================
MON_PROMPT:     DB      '> ',0

MSG_HELP:
        DB      CR,LF
        DB      'JX Monitor Commands:',CR,LF
        DB      '  d <addr> [<end>]    Hex dump memory',CR,LF
        DB      '  t [<start> <end>]   RAM test (destructive)',CR,LF
        DB      '  w <addr> <bb> ..    Write bytes',CR,LF
        DB      '  g <addr>            Go (execute)',CR,LF
        DB      '  m                   Memory info',CR,LF
        DB      '  cls                 Clear screen',CR,LF
        DB      '  ? or help           This message',CR,LF
        DB      CR,LF
        DB      'Addresses and bytes are hex.',CR,LF,0

MSG_UNK:        DB      '? ',0
MSG_DERR:       DB      'Usage: d <addr> [<end>]',CR,LF,0
MSG_TERR:       DB      'Usage: t [<start> <end>]',CR,LF,0
MSG_WERR:       DB      'Usage: w <addr> <byte> ...',CR,LF,0
MSG_GERR:       DB      'Usage: g <addr>',CR,LF,0

MSG_TSRT:       DB      'Testing ',0
MSG_TFER:       DB      'FAIL at ',0
MSG_TDNE:       DB      'Test complete: ',0
MSG_TNOE:       DB      'no errors.',CR,LF,0
MSG_TERP:       DB      ' error(s).',CR,LF,0

MSG_MLYT:       DB      CR,LF,'Memory Layout:',CR,LF,0
MSG_MTOT:       DB      '  Total: ',0
MSG_MKB:        DB      'KB',CR,LF,0
MSG_MFRL:       DB      '  Free:  ',0
MSG_MFRR:       DB      '  (RAM)',CR,LF,0
        IF VIDEO_BASE
MSG_MVDL:       DB      '  Video: ',0
MSG_MVDR:       DB      '  (VDM-1)',CR,LF,0
        ENDIF
MSG_MMNL:       DB      '  Monitor: ',0

;========================================================
; End of monitor.asm
;========================================================
