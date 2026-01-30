;========================================================
; JX Operating System - BIOS Stub
;========================================================
; This is a minimal BIOS stub for the cpmsim simulator.
; It provides the basic BIOS jump table and console I/O.
;
; The BIOS is assembled to run at BIOS_BASE, which is
; set via the -dBIOS_BASE=xxxx assembler flag.
;========================================================

;--------------------------------------------------------
; BIOS_BASE and BDOS_BASE are passed via assembler flags
; Example: -dBIOS_BASE=0FE00H -dBDOS_BASE=0F600H
;--------------------------------------------------------

        ORG     BIOS_BASE

;--------------------------------------------------------
; I/O Ports (cpmsim specific)
;--------------------------------------------------------
CONSTAT         EQU     0       ; Console status port
CONDATA         EQU     1       ; Console data port

; Disk I/O ports
FDC_DRIVE       EQU     10      ; Drive select
FDC_TRACK       EQU     11      ; Track number
FDC_SECTOR      EQU     12      ; Sector number
FDC_CMD         EQU     13      ; Command
FDC_STATUS      EQU     14      ; Status
DMA_LO          EQU     15      ; DMA address low byte
DMA_HI          EQU     16      ; DMA address high byte

; ASCII constants
CR              EQU     0DH
LF              EQU     0AH

; CCP (Console Command Processor) constants
CCP_BACKUP      EQU     0E000H  ; Backup location for CCP (high memory)
CCP_SIZE        EQU     2048    ; 2KB max for CCP

;========================================================
; BIOS Jump Table
;========================================================
; Each entry is exactly 3 bytes (JMP instruction)
;========================================================
BIOS_TABLE:
        JMP     BOOT            ; +00: Cold boot
        JMP     WBOOT           ; +03: Warm boot
        JMP     CONST           ; +06: Console status
        JMP     CONIN           ; +09: Console input
        JMP     CONOUT          ; +0C: Console output
        JMP     LIST            ; +0F: List output
        JMP     PUNCH           ; +12: Punch output
        JMP     READER          ; +15: Reader input
        JMP     HOME            ; +18: Home disk
        JMP     SELDSK          ; +1B: Select disk
        JMP     SETTRK          ; +1E: Set track
        JMP     SETSEC          ; +21: Set sector
        JMP     SETDMA          ; +24: Set DMA address
        JMP     READ            ; +27: Read sector
        JMP     WRITE           ; +2A: Write sector
        JMP     LISTST          ; +2D: List status
        JMP     SECTRN          ; +30: Sector translate

;========================================================
; BIOS Variables
;========================================================
DISKNO:         DB      0       ; Current disk number
TRACK:          DW      0       ; Current track
SECTOR:         DW      0       ; Current sector
DMAADDR:        DW      0080H   ; Current DMA address
DETECTED_MEM:   DW      0       ; Detected memory top

;========================================================
; Cold Boot
;========================================================
BOOT:
        DI                      ; Disable interrupts
        LXI     SP,BIOS_BASE    ; Temporary stack at BIOS base

        ; Print boot banner
        LXI     H,MSG_BANNER
        CALL    PRMSG

        ; Print scanning message
        LXI     H,MSG_SCAN
        CALL    PRMSG

        ; Detect memory (prints * for each 4KB)
        CALL    MEMPROBE        ; Returns HL = MEMTOP
        SHLD    DETECTED_MEM    ; Store for later use

        ; Print newline after progress
        LXI     H,MSG_CRLF
        CALL    PRMSG

        ; Print memory total
        CALL    PRMSIZ

        ; Print memory map
        CALL    PRMMAP

        ; Initialize Page Zero
        CALL    INIT_PAGE0

        ; Backup CCP to high memory for warm boot reload
        CALL    BACKUP_CCP

        ; Print ready message
        LXI     H,MSG_READY
        CALL    PRMSG

        ; Jump to CCP at TPA_BASE
        JMP     0100H           ; Start CCP

;========================================================
; DELAY_500MS - Approximately 500ms delay
; Destroys: A, D, E
;========================================================
DELAY_500MS:
        PUSH    B               ; Save B register
        LXI     D,0FFFFH        ; Outer loop counter (65535)
DELAY_OUTER:
        MVI     A,20H           ; Inner loop counter (32)
DELAY_INNER:
        DCR     A               ; Decrement inner counter
        JNZ     DELAY_INNER     ; Loop until zero
        DCX     D               ; Decrement outer counter
        MOV     A,D
        ORA     E               ; Check if DE = 0
        JNZ     DELAY_OUTER     ; Continue if not zero
        POP     B               ; Restore B register
        RET

;========================================================
; Warm Boot
;========================================================
WBOOT:
        ; Reinitialize Page Zero vectors
        CALL    INIT_PAGE0

        ; Reload CCP from backup to TPA
        CALL    LOAD_CCP

        ; Print newline for clean prompt
        MVI     C,0DH
        CALL    CONOUT
        MVI     C,0AH
        CALL    CONOUT

        ; Jump to CCP
        JMP     0100H

;========================================================
; Initialize Page Zero
;========================================================
INIT_PAGE0:
        ; Set warm boot vector at 0x0000
        MVI     A,0C3H          ; JMP instruction
        STA     0000H
        LXI     H,WBOOT
        SHLD    0001H

        ; Set BDOS entry vector at 0x0005
        MVI     A,0C3H          ; JMP instruction
        STA     0005H
        LXI     H,BDOS_BASE
        SHLD    0006H

        ; Initialize I/O byte
        XRA     A
        STA     0003H

        ; Initialize current disk
        STA     0004H

        RET

;========================================================
; BACKUP_CCP - Copy CCP from TPA to backup area
;========================================================
; Copies CCP_SIZE bytes from 0x0100 to CCP_BACKUP
; This is called during cold boot to save CCP for warm boot
; Destroys: A, B, C, D, E, H, L
;========================================================
BACKUP_CCP:
        LXI     H,0100H         ; Source: TPA_BASE (where CCP is loaded)
        LXI     D,CCP_BACKUP    ; Dest: Backup location
        LXI     B,CCP_SIZE      ; Count: CCP size

BACKUP_LOOP:
        MOV     A,M             ; Read byte from source
        STAX    D               ; Write byte to dest
        INX     H               ; Increment source
        INX     D               ; Increment dest
        DCX     B               ; Decrement count
        MOV     A,B
        ORA     C               ; Check if BC = 0
        JNZ     BACKUP_LOOP

        RET

;========================================================
; LOAD_CCP - Reload CCP from backup area to TPA
;========================================================
; Copies CCP_SIZE bytes from CCP_BACKUP to 0x0100
; This is called during warm boot to restore CCP
; Destroys: A, B, C, D, E, H, L
;========================================================
LOAD_CCP:
        LXI     H,CCP_BACKUP    ; Source: CCP backup location
        LXI     D,0100H         ; Dest: TPA_BASE
        LXI     B,CCP_SIZE      ; Count: CCP size

LOAD_LOOP:
        MOV     A,M             ; Read byte from source
        STAX    D               ; Write byte to dest
        INX     H               ; Increment source
        INX     D               ; Increment dest
        DCX     B               ; Decrement count
        MOV     A,B
        ORA     C               ; Check if BC = 0
        JNZ     LOAD_LOOP

        RET

;========================================================
; MEMPROBE - Detect top of RAM with progress display
; Output: HL = first invalid address (MEMTOP)
; Prints '*' for each 4KB tested
; Destroys: A, B, C, HL
;========================================================
MEMPROBE:
        LXI     H,08000H        ; Start at 32KB (minimum)
        MVI     C,0             ; Page counter (for 4KB = 16 pages)
MPRBLP:
        MOV     A,H
        ORA     A               ; H=0 means wrapped past 64KB
        JZ      MPRBDN

        MOV     A,M             ; Read current value
        MOV     B,A             ; Save it in B
        CMA                     ; Complement A
        MOV     M,A             ; Write complement
        CMP     M               ; Read back - match?
        MOV     M,B             ; Restore original value
        JNZ     MPRBDN          ; No match = no RAM here

        ; Check if we should print progress (every 16 pages = 4KB)
        INR     C               ; Increment page counter
        MOV     A,C
        ANI     0FH             ; Mask to lower 4 bits
        JNZ     MPRNXT          ; Not at 4KB boundary yet
        ; Print progress marker
        MVI     A,'*'
        OUT     CONDATA

MPRNXT:
        INR     H               ; Next 256-byte page
        JMP     MPRBLP

MPRBDN:
        RET                     ; HL = MEMTOP

;========================================================
; PRMSIZ - Print detected memory size
; Input: DETECTED_MEM contains MEMTOP
; Destroys: A, B, C, D, E, H, L
;========================================================
PRMSIZ:
        LXI     H,MSG_MEMORY    ; "Memory: "
        CALL    PRMSG

        LHLD    DETECTED_MEM    ; Get MEMTOP
        ; Convert to KB: divide by 1024 (shift right 10 bits)
        ; Since H already contains high byte, H = MEMTOP/256
        ; Divide H by 4 to get KB
        MOV     A,H
        ORA     A               ; Check for 64KB (H=0 means 256 pages = 64KB)
        JNZ     NOT_64K
        MVI     A,64            ; Special case: 64KB
        JMP     PRINT_KB
NOT_64K:
        RRC                     ; Divide by 2
        RRC                     ; Divide by 4 = KB
        ANI     03FH            ; Mask to 6 bits (max 63)
PRINT_KB:
        ; A now contains KB value (32-64)
        CALL    PRDEC   ; Print A as decimal

        LXI     H,MSG_KB        ; "KB"
        CALL    PRMSG
        RET

;========================================================
; PRMMAP - Display memory allocation map
; Shows: 0000-xxxx TPA, xxxx-xxxx BDOS, xxxx-FFFF BIOS
;========================================================
PRMMAP:
        ; Print TPA line: 0000-BDOS_BASE-1 TPA
        LXI     H,MSG_MAP0
        CALL    PRMSG
        LXI     H,BDOS_BASE-1   ; End of TPA
        CALL    PRADDR
        LXI     H,MSG_TPA
        CALL    PRMSG

        ; Print BDOS line: BDOS_BASE-BIOS_BASE-1 BDOS
        LXI     H,MSG_MAP1
        CALL    PRMSG
        LXI     H,BDOS_BASE
        CALL    PRADDR
        MVI     A,'-'
        OUT     CONDATA
        LXI     H,BIOS_BASE-1   ; End of BDOS
        CALL    PRADDR
        LXI     H,MSG_BDOS
        CALL    PRMSG

        ; Print BIOS line: BIOS_BASE-FFFF BIOS
        LXI     H,MSG_MAP1
        CALL    PRMSG
        LXI     H,BIOS_BASE
        CALL    PRADDR
        MVI     A,'-'
        OUT     CONDATA
        LXI     H,0FFFFH
        CALL    PRADDR
        LXI     H,MSG_BIOS
        CALL    PRMSG
        RET

;========================================================
; PRADDR - Print HL as 4-digit hex address
; Input: HL = address to print
; Destroys: A
;========================================================
PRADDR:
        MOV     A,H
        CALL    PRHEX
        MOV     A,L
        CALL    PRHEX
        RET

;========================================================
; PRHEX - Print A as 2-digit hex
; Input: A = byte to print
; Destroys: A
;========================================================
PRHEX:
        PUSH    PSW             ; Save original
        RRC                     ; Shift high nibble
        RRC
        RRC
        RRC
        CALL    PRNIB           ; Print high nibble
        POP     PSW             ; Restore
        CALL    PRNIB           ; Print low nibble
        RET

;========================================================
; PRNIB - Print low nibble of A as hex digit
; Input: A = value (low 4 bits used)
; Destroys: A
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
        OUT     CONDATA
        RET

;========================================================
; PRDEC - Print A register as decimal (0-99)
; Input: A = number to print
; Destroys: A, B
;========================================================
PRDEC:
        MVI     B,0             ; Tens counter
TENS_LOOP:
        CPI     10
        JC      PRINT_TENS      ; Less than 10, done counting
        SUI     10              ; Subtract 10
        INR     B               ; Increment tens
        JMP     TENS_LOOP
PRINT_TENS:
        PUSH    PSW             ; Save ones digit
        MOV     A,B
        ORA     A               ; Is tens zero?
        JZ      SKIP_TENS       ; Skip leading zero
        ADI     '0'             ; Convert to ASCII
        OUT     CONDATA
SKIP_TENS:
        POP     PSW             ; Restore ones digit
        ADI     '0'             ; Convert to ASCII
        OUT     CONDATA
        RET

;========================================================
; Console Status
; Returns: A = 0 if no char ready, FF if ready
;========================================================
CONST:
        IN      CONSTAT
        RET

;========================================================
; Console Input
; Returns: A = character read
;========================================================
CONIN:
        IN      CONSTAT         ; Check status
        ORA     A
        JZ      CONIN           ; Wait for character
        IN      CONDATA         ; Read character
        RET

;========================================================
; Console Output
; Input: C = character to output
;========================================================
CONOUT:
        MOV     A,C
        OUT     CONDATA
        RET

;========================================================
; List Device Output (stub)
;========================================================
LIST:
        MOV     A,C
        OUT     CONDATA         ; Send to console as fallback
        RET

;========================================================
; Punch Device Output (stub)
;========================================================
PUNCH:
        RET

;========================================================
; Reader Device Input (stub)
;========================================================
READER:
        MVI     A,1AH           ; Return EOF (Ctrl-Z)
        RET

;========================================================
; List Device Status (stub)
;========================================================
LISTST:
        MVI     A,0FFH          ; Always ready
        RET

;========================================================
; Home Disk Head
;========================================================
HOME:
        LXI     H,0
        SHLD    TRACK
        RET

;========================================================
; Select Disk
; Input: C = disk number (0=A, 1=B, ...)
; Output: HL = DPH address, or 0 if invalid
;========================================================
SELDSK:
        MOV     A,C
        CPI     1               ; Only drive A supported
        JNC     SELDSK_BAD
        STA     DISKNO
        OUT     FDC_DRIVE
        LXI     H,DPH0          ; Return DPH for drive A
        RET
SELDSK_BAD:
        LXI     H,0             ; Invalid drive
        RET

;========================================================
; Set Track
; Input: BC = track number
;========================================================
SETTRK:
        MOV     H,B
        MOV     L,C
        SHLD    TRACK
        RET

;========================================================
; Set Sector
; Input: BC = sector number
;========================================================
SETSEC:
        MOV     H,B
        MOV     L,C
        SHLD    SECTOR
        RET

;========================================================
; Set DMA Address
; Input: BC = DMA address
;========================================================
SETDMA:
        MOV     H,B
        MOV     L,C
        SHLD    DMAADDR
        RET

;========================================================
; Read Sector
; Output: A = 0 on success, 1 on error
;========================================================
READ:
        CALL    SETUP_DISK
        XRA     A               ; Read command = 0
        OUT     FDC_CMD
        IN      FDC_STATUS
        RET

;========================================================
; Write Sector
; Output: A = 0 on success, 1 on error
;========================================================
WRITE:
        CALL    SETUP_DISK
        MVI     A,1             ; Write command = 1
        OUT     FDC_CMD
        IN      FDC_STATUS
        RET

;========================================================
; Setup Disk I/O Ports
;========================================================
SETUP_DISK:
        LHLD    TRACK
        MOV     A,L
        OUT     FDC_TRACK

        LHLD    SECTOR
        MOV     A,L
        OUT     FDC_SECTOR

        LHLD    DMAADDR
        MOV     A,L
        OUT     DMA_LO
        MOV     A,H
        OUT     DMA_HI

        RET

;========================================================
; Sector Translate
; Input: BC = logical sector, DE = translate table addr
; Output: HL = physical sector
;========================================================
SECTRN:
        MOV     H,B             ; No translation
        MOV     L,C
        RET

;========================================================
; Print Message (null-terminated)
; Input: HL = message address
;========================================================
PRMSG:
        MOV     A,M
        ORA     A
        RZ
        OUT     CONDATA
        INX     H
        JMP     PRMSG

;========================================================
; Messages
;========================================================
MSG_BANNER:
        DB      CR,LF
        DB      'JX/8080. Version 0.1. (C) 2025 MrEppot'
        DB      CR,LF,LF,0

MSG_MEMORY:
        DB      'Memory: ',0

MSG_KB:
        DB      'KB',CR,LF,LF,0

MSG_SCAN:
        DB      'Scanning: ',0

MSG_CRLF:
        DB      CR,LF,0

MSG_MAP0:
        DB      '  0000-',0

MSG_MAP1:
        DB      '  ',0

MSG_TPA:
        DB      '  TPA',CR,LF,0

MSG_BDOS:
        DB      '  BDOS',CR,LF,0

MSG_BIOS:
        DB      '  BIOS',CR,LF,0

MSG_HALT:
        DB      CR,LF
        DB      'System halted.',CR,LF,0

MSG_READY:
        DB      CR,LF
        DB      'System ready.',CR,LF,0

;========================================================
; Disk Parameter Header (DPH) for Drive A
;========================================================
DPH0:
        DW      0               ; XLT - no translation
        DW      0,0,0           ; Scratch area
        DW      DIRBUF          ; Directory buffer
        DW      DPB0            ; Disk Parameter Block
        DW      0               ; CSV - no checksum
        DW      ALV0            ; Allocation vector

;========================================================
; Disk Parameter Block (DPB) for 8" SSSD
;========================================================
DPB0:
        DW      26              ; SPT - sectors per track
        DB      3               ; BSH - block shift (1K blocks)
        DB      7               ; BLM - block mask
        DB      0               ; EXM - extent mask
        DW      242             ; DSM - total blocks - 1
        DW      63              ; DRM - directory entries - 1
        DB      0C0H            ; AL0 - allocation bitmap
        DB      0               ; AL1
        DW      16              ; CKS - checksum vector size
        DW      2               ; OFF - reserved tracks

;========================================================
; Disk Buffers
;========================================================
DIRBUF: DS      128             ; Directory buffer
ALV0:   DS      32              ; Allocation vector

;========================================================
        END
