;========================================================
; JX Operating System - System Definitions
;========================================================
; This file contains common definitions used throughout
; the JX operating system. Include this file in all
; assembly source files.
;
; Memory addresses are set via assembler defines:
;   -dMEMTOP=xxxx -dBIOS_BASE=xxxx -dBDOS_BASE=xxxx
;========================================================

;--------------------------------------------------------
; Page Zero Addresses
;--------------------------------------------------------
BOOT_ENTRY      EQU     0000H   ; Warm boot entry point
IOBYTE          EQU     0003H   ; I/O configuration byte
CDISK           EQU     0004H   ; Current disk
BDOS_ENTRY      EQU     0005H   ; BDOS entry point

; RST vectors
RST1            EQU     0008H
RST2            EQU     0010H
RST3            EQU     0018H
RST4            EQU     0020H
RST5            EQU     0028H
RST6            EQU     0030H
RST7            EQU     0038H   ; Interrupt vector

; Default FCB and DMA
DFCB            EQU     005CH   ; Default File Control Block
DFCB2           EQU     006CH   ; Second default FCB
DBUF            EQU     0080H   ; Default DMA buffer

; TPA
TPA_BASE        EQU     0100H   ; Transient Program Area start

;--------------------------------------------------------
; BDOS Function Numbers
;--------------------------------------------------------
; Console Functions
S_RESET         EQU     00H     ; System reset (warm boot)
C_READ          EQU     01H     ; Console input
C_WRITE         EQU     02H     ; Console output
R_READ          EQU     03H     ; Reader input
P_WRITE         EQU     04H     ; Punch output
L_WRITE         EQU     05H     ; List output
C_RAWIO         EQU     06H     ; Direct console I/O
C_GETIOB        EQU     07H     ; Get I/O byte
C_SETIOB        EQU     08H     ; Set I/O byte
C_WRITESTR      EQU     09H     ; Print string
C_READSTR       EQU     0AH     ; Read console buffer
C_STAT          EQU     0BH     ; Get console status

; Disk Functions
D_RESET         EQU     0DH     ; Reset disk system
D_SELECT        EQU     0EH     ; Select disk
F_OPEN          EQU     0FH     ; Open file
F_CLOSE         EQU     10H     ; Close file
F_SFIRST        EQU     11H     ; Search for first
F_SNEXT         EQU     12H     ; Search for next
F_DELETE        EQU     13H     ; Delete file
F_READ          EQU     14H     ; Read sequential
F_WRITE         EQU     15H     ; Write sequential
F_MAKE          EQU     16H     ; Create file
F_RENAME        EQU     17H     ; Rename file
D_LOGIVEC       EQU     18H     ; Get login vector
D_GETCUR        EQU     19H     ; Get current drive
F_SETDMA        EQU     1AH     ; Set DMA address
D_GETALV        EQU     1BH     ; Get allocation vector
D_WRPROT        EQU     1CH     ; Write protect disk
D_GETROV        EQU     1DH     ; Get read-only vector
F_SETATT        EQU     1EH     ; Set file attributes
D_GETDPB        EQU     1FH     ; Get disk parameter block
F_GETUSER       EQU     20H     ; Get/set user number
F_RREAD         EQU     21H     ; Read random
F_RWRITE        EQU     22H     ; Write random
F_SIZE          EQU     23H     ; Compute file size
F_SETREC        EQU     24H     ; Set random record

; JX Extended Functions
S_GETVER        EQU     30H     ; Get system version
S_GETTPA        EQU     31H     ; Get TPA top address
S_GETMEM        EQU     32H     ; Get total memory

;--------------------------------------------------------
; FCB Structure Offsets
;--------------------------------------------------------
FCB_DR          EQU     0       ; Drive (0=default, 1=A, ...)
FCB_FN          EQU     1       ; Filename (8 bytes)
FCB_FT          EQU     9       ; File type (3 bytes)
FCB_EX          EQU     12      ; Extent number
FCB_S1          EQU     13      ; Reserved
FCB_S2          EQU     14      ; Reserved
FCB_RC          EQU     15      ; Record count
FCB_AL          EQU     16      ; Allocation map (16 bytes)
FCB_CR          EQU     32      ; Current record
FCB_RN          EQU     33      ; Random record (3 bytes)
FCB_SIZE        EQU     36      ; Total FCB size

;--------------------------------------------------------
; BIOS Jump Table Offsets (from BIOS_BASE)
;--------------------------------------------------------
BIOS_BOOT       EQU     00H     ; Cold boot
BIOS_WBOOT      EQU     03H     ; Warm boot
BIOS_CONST      EQU     06H     ; Console status
BIOS_CONIN      EQU     09H     ; Console input
BIOS_CONOUT     EQU     0CH     ; Console output
BIOS_LIST       EQU     0FH     ; List output
BIOS_PUNCH      EQU     12H     ; Punch output
BIOS_READER     EQU     15H     ; Reader input
BIOS_HOME       EQU     18H     ; Home disk head
BIOS_SELDSK     EQU     1BH     ; Select disk
BIOS_SETTRK     EQU     1EH     ; Set track
BIOS_SETSEC     EQU     21H     ; Set sector
BIOS_SETDMA     EQU     24H     ; Set DMA address
BIOS_READ       EQU     27H     ; Read sector
BIOS_WRITE      EQU     2AH     ; Write sector
BIOS_LISTST     EQU     2DH     ; List device status
BIOS_SECTRN     EQU     30H     ; Sector translate

;--------------------------------------------------------
; ASCII Character Codes
;--------------------------------------------------------
NUL             EQU     00H
BEL             EQU     07H
BS              EQU     08H
TAB             EQU     09H
LF              EQU     0AH
CR              EQU     0DH
ESC             EQU     1BH
SPC             EQU     20H
DEL             EQU     7FH

;--------------------------------------------------------
; I/O Ports (simulator-specific, override in BIOS)
;--------------------------------------------------------
CONSTAT         EQU     0       ; Console status port
CONDATA         EQU     1       ; Console data port

;--------------------------------------------------------
; Useful Macros
;--------------------------------------------------------

; Print a single character
; Usage: PUTC 'A'
PUTC    MACRO   char
        MVI     E,char
        MVI     C,C_WRITE
        CALL    BDOS_ENTRY
        ENDM

; Print a newline (CR+LF)
NEWLINE MACRO
        MVI     E,CR
        MVI     C,C_WRITE
        CALL    BDOS_ENTRY
        MVI     E,LF
        MVI     C,C_WRITE
        CALL    BDOS_ENTRY
        ENDM

;========================================================
; End of system.inc
;========================================================
