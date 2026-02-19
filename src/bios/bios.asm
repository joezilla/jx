;========================================================
; JX Monitor - System Entry Point
;========================================================
; Single flat-binary monitor OS for Intel 8080.
;
; Provides:
;   - Serial I/O (configurable ports)
;   - VDM-1 video display (optional)
;   - Dual output: all stdout to both serial and video
;   - Interactive monitor commands
;
; Memory layout depends on BIOS_BASE:
;
;   BIOS_BASE > 0 (traditional, top of RAM):
;     0000-00FF  Page Zero (JMP WBOOT at 0000H)
;     0100-xxxx  Free RAM
;     xxxx-FFFF  Monitor OS (~3KB)
;
;   BIOS_BASE = 0 (load at zero):
;     0000-xxxx  Monitor OS (~3KB)
;     xxxx-FFFF  Free RAM
;
; Required assembler defines:
;   -dBIOS_BASE=xxxx    Monitor load address
;   -dSTACK_TOP=xxxx    Stack pointer initial value
;   -dMEMTOP=xxxx       Top of physical RAM
;   -dMEM_SIZE=xx       Memory size in KB
;
; Optional defines:
;   -dVIDEO_BASE=xxxx   Video framebuffer address
;   -dVIDEO_COLS=xx     Video columns
;   -dVIDEO_ROWS=xx     Video rows
;========================================================

        ORG     BIOS_BASE

;========================================================
; ASCII Constants
;========================================================
CR              EQU     0DH
LF              EQU     0AH

;========================================================
; BIOS Jump Table (0000H-000BH)
;========================================================
; CP/M-style vectors for loaded programs.
; When BIOS_BASE=0, the table is inline at ORG 0.
; When BIOS_BASE>0, INIT_PAGE0 writes it to page zero.
;========================================================
        IF BIOS_BASE = 0
JT_WBOOT:       JMP     BOOT            ; 0000 - patched to WBOOT after init
JT_CONST:       JMP     CONST           ; 0003
JT_GCHR:        JMP     GETCHAR         ; 0006
JT_PCHR:        JMP     PUTCHAR         ; 0009
        ENDIF

;========================================================
; Cold Boot
;========================================================
BOOT:
        DI                      ; Disable interrupts
        LXI     SP,STACK_TOP    ; Initialize stack pointer

        ; Initialize serial port (8251 USART init if SIO_8251=1)
        CALL    SIO_INIT

        ; Print banner via serial only (video not yet initialized)
        LXI     H,MSG_BANNER
        CALL    PRMSG

        ; Detect memory
        LXI     H,MSG_SCAN
        CALL    PRMSG
        CALL    MEMPROBE
        SHLD    DETECTED_MEM
        LXI     H,MSG_CRLF
        CALL    PRMSG

        ; Print memory size
        CALL    PRMSIZ

        IF VIDEO_BASE
        ; Initialize video display
        CALL    V_INIT
        LXI     H,MSG_BANNER
        CALL    V_PRINTS        ; Video-only: banner already on serial via PRMSG
        LXI     H,MSG_VIDEO
        CALL    PRINTS          ; Both outputs: video info goes to serial too
        ENDIF

        ; Set up Page Zero (only when monitor is not at address 0)
        IF BIOS_BASE
        CALL    INIT_PAGE0
        ENDIF

        ; Print memory map
        CALL    PRMMAP

        ; Patch jump table warm boot vector (BIOS_BASE=0 only)
        IF BIOS_BASE = 0
        MVI     A,0C3H          ; JMP opcode
        STA     0000H
        LXI     H,WBOOT
        SHLD    0001H
        ENDIF

        ; System ready - enter monitor
        LXI     H,MSG_READY
        CALL    PRINTS

        JMP     MONITOR

;========================================================
; Warm Boot (re-enter monitor)
;========================================================
WBOOT:
        LXI     SP,STACK_TOP
        IF BIOS_BASE
        CALL    INIT_PAGE0
        ENDIF
        CALL    PRCRLF
        JMP     MONITOR

;========================================================
; Initialize Page Zero
;========================================================
; Sets JMP WBOOT at 0000H so programs can return to
; monitor via JMP 0000H.
; Only assembled when BIOS_BASE > 0.
;========================================================
        IF BIOS_BASE
INIT_PAGE0:
        MVI     A,0C3H          ; JMP opcode
        STA     0000H           ; WBOOT vector
        LXI     H,WBOOT
        SHLD    0001H
        MVI     A,0C3H
        STA     0003H           ; CONST vector
        LXI     H,CONST
        SHLD    0004H
        MVI     A,0C3H
        STA     0006H           ; GETCHAR vector
        LXI     H,GETCHAR
        SHLD    0007H
        MVI     A,0C3H
        STA     0009H           ; PUTCHAR vector
        LXI     H,PUTCHAR
        SHLD    000AH
        RET
        ENDIF

;========================================================
; PUTCHAR - Dual output (serial + video)
;========================================================
; Input:  A = character to output
; Destroys: C (serial uses C for CONOUT)
;========================================================
PUTCHAR:
        PUSH    PSW
        PUSH    H               ; Save HL (V_PUTCH destroys it)
        MOV     C,A
        CALL    CONOUT          ; Serial output
        IF VIDEO_BASE
        POP     H
        POP     PSW
        PUSH    PSW
        PUSH    H
        PUSH    B               ; Save BC (V_SCROLL destroys B)
        PUSH    D               ; Save DE (V_PUTCH destroys DE)
        CALL    V_PUTCH         ; Video output
        POP     D
        POP     B
        ENDIF
        POP     H
        POP     PSW
        RET

;========================================================
; GETCHAR - Read from serial (keyboard)
;========================================================
; Output: A = character
;========================================================
GETCHAR:
        CALL    CONIN
        RET

;========================================================
; MEMPROBE - Detect top of RAM
;========================================================
; Probes upward in 256-byte pages.
; Prints '*' for each 4KB found.
; Output: HL = first invalid address (MEMTOP)
; Destroys: A, B, C, H, L
;========================================================
MEMPROBE:
        IF BIOS_BASE
        ; Traditional layout: probe from 32KB upward
        LXI     H,08000H
        ELSE
        ; Load-at-zero: probe from first page after monitor code
        LXI     H,CODE_END
        MOV     A,L
        ORA     A
        JZ      MPR_AL          ; Already page-aligned
        INR     H               ; Round up to next 256-byte page
        MVI     L,0
MPR_AL:
        ENDIF
        MVI     C,0             ; Page counter
MPRBLP:
        MOV     A,H
        ORA     A               ; H=0 means wrapped past 64KB
        JZ      MPRBDN

        MOV     A,M             ; Read current value
        MOV     B,A             ; Save
        CMA                     ; Complement
        MOV     M,A             ; Write complement
        CMP     M               ; Read back
        MOV     M,B             ; Restore original
        JNZ     MPRBDN          ; No match = no RAM

        ; Progress: '*' every 4KB (16 pages)
        INR     C
        MOV     A,C
        ANI     0FH
        JNZ     MPRNXT
        PUSH    B
        MVI     C,'*'
        CALL    CONOUT          ; Serial only (video may not be init)
        POP     B
        MVI     C,0

MPRNXT:
        INR     H               ; Next 256-byte page
        JMP     MPRBLP

MPRBDN:
        RET

;========================================================
; PRMSIZ - Print detected memory size
;========================================================
PRMSIZ:
        LXI     H,MSG_MEMORY
        CALL    PRMSG

        LHLD    DETECTED_MEM
        MOV     A,H
        ORA     A
        JNZ     PMSZ1
        MVI     A,64
        JMP     PMSZ2
PMSZ1:
        RRC
        RRC
        ANI     03FH
PMSZ2:
        CALL    PRDEC
        LXI     H,MSG_KB
        CALL    PRMSG
        RET

;========================================================
; PRMMAP - Print memory map
;========================================================
; Dynamically prints addresses based on build configuration.
;========================================================
PRMMAP:
        IF BIOS_BASE
        ; Traditional layout: Page Zero, Free RAM, [Video], Monitor
        LXI     H,MSG_MAP_PZ
        CALL    PRINTS

        ; Free RAM: 0100-<BIOS_BASE-1>
        LXI     H,MSG_MAP_2SP
        CALL    PRINTS
        LXI     H,0100H
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        LXI     H,BIOS_BASE-1
        CALL    PRHEX16
        LXI     H,MSG_MAP_RAM
        CALL    PRINTS

        ELSE
        ; Load-at-zero: Monitor, Free RAM, [Video]

        ; Monitor: 0000-<CODE_END-1>
        LXI     H,MSG_MAP_2SP
        CALL    PRINTS
        LXI     H,0000H
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        LXI     H,CODE_END-1
        CALL    PRHEX16
        LXI     H,MSG_MAP_MON
        CALL    PRINTS

        ; Free RAM: <CODE_END>-<top>
        LXI     H,MSG_MAP_2SP
        CALL    PRINTS
        LXI     H,CODE_END
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        LXI     H,MEMTOP-1
        CALL    PRHEX16
        LXI     H,MSG_MAP_RAM
        CALL    PRINTS

        ENDIF

        IF VIDEO_BASE
        LXI     H,MSG_MAP_2SP
        CALL    PRINTS
        LXI     H,VIDEO_BASE
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        LXI     H,VIDEO_BASE+VIDEO_SIZE-1
        CALL    PRHEX16
        LXI     H,MSG_MAP_VID
        CALL    PRINTS
        ENDIF

        IF BIOS_BASE
        ; Monitor line (traditional layout)
        LXI     H,MSG_MAP_2SP
        CALL    PRINTS
        LXI     H,BIOS_BASE
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        LXI     H,CODE_END-1
        CALL    PRHEX16
        LXI     H,MSG_MAP_MON
        CALL    PRINTS
        ENDIF

        RET

;========================================================
; PRMSG - Print null-terminated string via serial only
;========================================================
; Used during early boot before video is initialized.
; After boot, use PRINTS (which goes through PUTCHAR).
;========================================================
PRMSG:
        MOV     A,M
        ORA     A
        RZ
        MOV     C,A
        CALL    CONOUT
        INX     H
        JMP     PRMSG

;========================================================
; V_PRINTS - Print null-terminated string via video only
;========================================================
; Used for video-init banner (already printed on serial).
; Input:  HL = pointer to null-terminated string
; Destroys: A, B, C, D, E, H, L
;========================================================
        IF VIDEO_BASE
V_PRINTS:
        MOV     A,M
        ORA     A
        RZ
        PUSH    H
        CALL    V_PUTCH
        POP     H
        INX     H
        JMP     V_PRINTS
        ENDIF

;========================================================
; PRDEC - Print A as decimal (0-99)
;========================================================
; Simple decimal for boot messages (memory KB).
;========================================================
PRDEC:
        MVI     B,0
PRDT:
        CPI     10
        JC      PRDT2
        SUI     10
        INR     B
        JMP     PRDT
PRDT2:
        PUSH    PSW
        MOV     A,B
        ORA     A
        JZ      PRDT3
        ADI     '0'
        MOV     C,A
        CALL    CONOUT
PRDT3:
        POP     PSW
        ADI     '0'
        MOV     C,A
        CALL    CONOUT
        RET

;========================================================
; BIOS Variables
;========================================================
DETECTED_MEM:   DW      0       ; Detected memory top

;========================================================
; Include sub-modules
;========================================================
        INCLUDE serial.asm
        INCLUDE video.asm
        INCLUDE ../lib/print.asm
        INCLUDE ../lib/string.asm
        INCLUDE ../monitor.asm

;========================================================
; Tiny BASIC (optional, built-in)
;========================================================
; Note: INCLUDE is outside IF ENABLE_BASIC because z80asm
; has issues with IF/ENDIF nesting across INCLUDE boundaries.
; tinybasic.asm checks ENABLE_BASIC internally.
        IF BIOS_BASE = 0
BASIC_VAR       EQU     02000H
        ELSE
BASIC_VAR       EQU     00100H
        ENDIF
BASIC_TEXT       EQU     BASIC_VAR + 0100H

        INCLUDE ../basic/tinybasic.asm

;========================================================
; Boot Messages
;========================================================
MSG_BANNER:
        DB      CR,LF
        DB      'JX/8080 Monitor v'
        DB      '0'+VER_MAJOR,'.','0'+VER_MINOR
        DB      CR,LF,0

MSG_MEMORY:
        DB      'Memory: ',0

MSG_KB:
        DB      'KB',CR,LF,0

MSG_SCAN:
        DB      'Scanning: ',0

MSG_CRLF:
        DB      CR,LF,0

MSG_READY:
        DB      CR,LF,'Type ? for help.',CR,LF,0

        IF VIDEO_BASE
MSG_VIDEO:
        DB      'Video: VDM-1 64x16 at C000',CR,LF,0
        ENDIF

; Memory map fragments (addresses printed dynamically)
        IF BIOS_BASE
MSG_MAP_PZ:
        DB      '  0000-00FF  Page Zero',CR,LF,0
        ENDIF
MSG_MAP_2SP:
        DB      '  ',0
MSG_MAP_RAM:
        DB      '  Free RAM',CR,LF,0
MSG_MAP_MON:
        DB      '  Monitor',CR,LF,0
        IF VIDEO_BASE
MSG_MAP_VID:
        DB      '  Video',CR,LF,0
        ENDIF

;========================================================
; CODE_END - marks the end of all monitor code and data.
; Used to compute free RAM boundaries when BIOS_BASE=0.
;========================================================
CODE_END:

;========================================================
        END
;========================================================
