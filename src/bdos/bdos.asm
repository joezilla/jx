;========================================================
; JX Operating System - BDOS Stub
;========================================================
; This is a minimal BDOS stub that provides basic
; console I/O services. It will be expanded to include
; full file system support.
;
; The BDOS is assembled to run at BDOS_BASE, which is
; set via the -dBDOS_BASE=xxxx assembler flag.
;========================================================

;--------------------------------------------------------
; Ensure addresses are defined
;--------------------------------------------------------
IFNDEF BDOS_BASE
BDOS_BASE       EQU     0F600H  ; Default for 64KB
ENDIF

IFNDEF BIOS_BASE
BIOS_BASE       EQU     0FE00H  ; Default for 64KB
ENDIF

IFNDEF TPA_TOP
TPA_TOP         EQU     0F500H  ; Default for 64KB
ENDIF

        ORG     BDOS_BASE

;--------------------------------------------------------
; BIOS Jump Table Offsets
;--------------------------------------------------------
BIOS_CONST      EQU     BIOS_BASE+06H
BIOS_CONIN      EQU     BIOS_BASE+09H
BIOS_CONOUT     EQU     BIOS_BASE+0CH
BIOS_LIST       EQU     BIOS_BASE+0FH

;--------------------------------------------------------
; ASCII Constants
;--------------------------------------------------------
CR              EQU     0DH
LF              EQU     0AH
CTRLC           EQU     03H
CTRLZ           EQU     1AH

;========================================================
; BDOS Entry Point
;========================================================
; Called via: CALL 0005H
; Input:  C = function number
;         DE = parameter (if applicable)
;         E = single byte parameter (if applicable)
; Output: A = return value
;         HL = return value (16-bit)
;========================================================
BDOS_ENTRY:
        MOV     A,C             ; Get function number
        CPI     33H             ; Check range
        JNC     BDOS_INVALID    ; Invalid function

        ; Save registers
        PUSH    B
        PUSH    D
        PUSH    H

        ; Calculate jump table offset
        MOV     L,A
        MVI     H,0
        DAD     H               ; *2
        LXI     B,FUNC_TABLE
        DAD     B

        ; Get function address
        MOV     A,M
        INX     H
        MOV     H,M
        MOV     L,A

        ; Restore DE for parameter passing
        POP     B               ; Was H
        PUSH    B
        POP     D
        PUSH    D
        XCHG
        POP     D
        POP     D
        POP     B
        PUSH    B
        PUSH    D
        PUSH    H

        ; Jump to function
        XCHG
        POP     H
        XCHG
        POP     D
        POP     B
        PCHL

BDOS_INVALID:
        MVI     A,0FFH
        LXI     H,0FFFFH
        RET

;========================================================
; Function Jump Table
;========================================================
FUNC_TABLE:
        DW      F_RESET         ; 00 - System reset
        DW      F_CONIN         ; 01 - Console input
        DW      F_CONOUT        ; 02 - Console output
        DW      F_READER        ; 03 - Reader input
        DW      F_PUNCH         ; 04 - Punch output
        DW      F_LIST          ; 05 - List output
        DW      F_RAWIO         ; 06 - Direct console I/O
        DW      F_GETIOB        ; 07 - Get I/O byte
        DW      F_SETIOB        ; 08 - Set I/O byte
        DW      F_PRINT         ; 09 - Print string
        DW      F_READLN        ; 0A - Read console buffer
        DW      F_CONST         ; 0B - Console status
        DW      F_GETVER        ; 0C - Get version (extension)
        DW      F_DSKRESET      ; 0D - Disk reset
        DW      F_SELDSK        ; 0E - Select disk
        DW      F_OPEN          ; 0F - Open file
        DW      F_CLOSE         ; 10 - Close file
        DW      F_SFIRST        ; 11 - Search first
        DW      F_SNEXT         ; 12 - Search next
        DW      F_DELETE        ; 13 - Delete file
        DW      F_READ          ; 14 - Read sequential
        DW      F_WRITE         ; 15 - Write sequential
        DW      F_MAKE          ; 16 - Create file
        DW      F_RENAME        ; 17 - Rename file
        DW      F_LOGIVEC       ; 18 - Get login vector
        DW      F_CURDSK        ; 19 - Get current disk
        DW      F_SETDMA        ; 1A - Set DMA address
        DW      F_GETALV        ; 1B - Get allocation vector
        DW      F_WRPROT        ; 1C - Write protect disk
        DW      F_GETROV        ; 1D - Get read-only vector
        DW      F_SETATTR       ; 1E - Set file attributes
        DW      F_GETDPB        ; 1F - Get disk param block
        DW      F_GETUSER       ; 20 - Get/set user
        DW      F_RREAD         ; 21 - Read random
        DW      F_RWRITE        ; 22 - Write random
        DW      F_SIZE          ; 23 - Compute file size
        DW      F_SETREC        ; 24 - Set random record
        ; Extended functions (reserved)
        DW      F_STUB          ; 25
        DW      F_STUB          ; 26
        DW      F_STUB          ; 27
        DW      F_STUB          ; 28
        DW      F_STUB          ; 29
        DW      F_STUB          ; 2A
        DW      F_STUB          ; 2B
        DW      F_STUB          ; 2C
        DW      F_STUB          ; 2D
        DW      F_STUB          ; 2E
        DW      F_STUB          ; 2F
        ; JX Extended functions
        DW      F_JXVER         ; 30 - Get JX version
        DW      F_GETTPA        ; 31 - Get TPA top
        DW      F_GETMEM        ; 32 - Get total memory

;========================================================
; Function 00: System Reset
;========================================================
F_RESET:
        JMP     0000H           ; Warm boot

;========================================================
; Function 01: Console Input
;========================================================
F_CONIN:
        CALL    BIOS_CONIN
        MOV     L,A
        MVI     H,0
        RET

;========================================================
; Function 02: Console Output
;========================================================
F_CONOUT:
        MOV     C,E             ; Character in E
        CALL    BIOS_CONOUT
        RET

;========================================================
; Function 03: Reader Input (stub)
;========================================================
F_READER:
        MVI     A,CTRLZ         ; Return EOF
        MOV     L,A
        MVI     H,0
        RET

;========================================================
; Function 04: Punch Output (stub)
;========================================================
F_PUNCH:
        RET

;========================================================
; Function 05: List Output
;========================================================
F_LIST:
        MOV     C,E
        CALL    BIOS_LIST
        RET

;========================================================
; Function 06: Direct Console I/O
;========================================================
F_RAWIO:
        MOV     A,E
        CPI     0FFH            ; Input request?
        JZ      F_RAWIO_IN
        CPI     0FEH            ; Status request?
        JZ      F_RAWIO_STAT
        ; Output
        MOV     C,E
        CALL    BIOS_CONOUT
        RET
F_RAWIO_IN:
        CALL    BIOS_CONST
        ORA     A
        JZ      F_RAWIO_NONE
        CALL    BIOS_CONIN
        MOV     L,A
        MVI     H,0
        RET
F_RAWIO_NONE:
        XRA     A
        MOV     L,A
        MOV     H,A
        RET
F_RAWIO_STAT:
        CALL    BIOS_CONST
        MOV     L,A
        MVI     H,0
        RET

;========================================================
; Function 07: Get I/O Byte
;========================================================
F_GETIOB:
        LDA     0003H
        MOV     L,A
        MVI     H,0
        RET

;========================================================
; Function 08: Set I/O Byte
;========================================================
F_SETIOB:
        MOV     A,E
        STA     0003H
        RET

;========================================================
; Function 09: Print String (terminated by '$')
;========================================================
F_PRINT:
        XCHG                    ; HL = string address
F_PRINT_LOOP:
        MOV     A,M
        CPI     '$'
        RZ
        MOV     C,A
        CALL    BIOS_CONOUT
        INX     H
        JMP     F_PRINT_LOOP

;========================================================
; Function 0A: Read Console Buffer
;========================================================
F_READLN:
        XCHG                    ; HL = buffer address
        MOV     B,M             ; B = max length
        INX     H
        PUSH    H               ; Save count location
        INX     H               ; Point to data area
        MVI     C,0             ; C = current count
F_READLN_LOOP:
        CALL    BIOS_CONIN
        CPI     CR              ; Enter pressed?
        JZ      F_READLN_DONE
        CPI     08H             ; Backspace?
        JZ      F_READLN_BS
        CPI     7FH             ; Delete?
        JZ      F_READLN_BS
        ; Check if buffer full
        MOV     A,C
        CMP     B
        JNC     F_READLN_LOOP   ; Buffer full, ignore
        ; Store character
        CALL    BIOS_CONIN      ; Re-read (already in A)
        MOV     M,A
        INX     H
        INR     C
        ; Echo character
        PUSH    B
        MOV     C,A
        CALL    BIOS_CONOUT
        POP     B
        JMP     F_READLN_LOOP
F_READLN_BS:
        MOV     A,C
        ORA     A
        JZ      F_READLN_LOOP   ; Nothing to delete
        DCR     C
        DCX     H
        ; Echo backspace sequence
        PUSH    B
        MVI     C,08H
        CALL    BIOS_CONOUT
        MVI     C,' '
        CALL    BIOS_CONOUT
        MVI     C,08H
        CALL    BIOS_CONOUT
        POP     B
        JMP     F_READLN_LOOP
F_READLN_DONE:
        POP     H               ; Get count location
        MOV     M,C             ; Store count
        RET

;========================================================
; Function 0B: Console Status
;========================================================
F_CONST:
        CALL    BIOS_CONST
        MOV     L,A
        MVI     H,0
        RET

;========================================================
; Function 0C: Get Version
;========================================================
F_GETVER:
        LXI     H,0022H         ; CP/M 2.2 compatible
        MOV     A,L
        RET

;========================================================
; Disk Functions (stubs - return error)
;========================================================
F_DSKRESET:
F_SELDSK:
F_OPEN:
F_CLOSE:
F_SFIRST:
F_SNEXT:
F_DELETE:
F_READ:
F_WRITE:
F_MAKE:
F_RENAME:
F_LOGIVEC:
F_CURDSK:
F_SETDMA:
F_GETALV:
F_WRPROT:
F_GETROV:
F_SETATTR:
F_GETDPB:
F_GETUSER:
F_RREAD:
F_RWRITE:
F_SIZE:
F_SETREC:
F_STUB:
        MVI     A,0FFH          ; Return error
        LXI     H,0FFFFH
        RET

;========================================================
; Function 30: Get JX Version
;========================================================
F_JXVER:
        LXI     H,0001H         ; JX version 0.1
        MOV     A,L
        RET

;========================================================
; Function 31: Get TPA Top
;========================================================
F_GETTPA:
        LXI     H,TPA_TOP
        RET

;========================================================
; Function 32: Get Total Memory
;========================================================
F_GETMEM:
IFDEF MEMTOP
        LXI     H,MEMTOP
ELSE
        LXI     H,0             ; 64KB (wraps to 0)
ENDIF
        RET

;========================================================
        END
