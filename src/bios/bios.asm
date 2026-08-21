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
;   BIOS_BASE > 0 (ROM-capable, e.g. monitor in an EPROM):
;     0000-00FF     Page Zero (JMP WBOOT at 0000H)
;     0100-DATA_END Mutable data segment (RAM - see below)
;     DATA_END-xxxx Free RAM (below the monitor)
;     BIOS_BASE-    Monitor code (~3KB, may be ROM-resident)
;       CODE_END
;     CODE_END-xxxx Free RAM (above the monitor, if any)
;
;   BIOS_BASE = 0 (load at zero, RAM-resident):
;     0000-xxxx  Monitor OS + data (~3KB)
;     xxxx-FFFF  Free RAM
;
; Because BIOS_BASE > 0 is intended to support ROM-resident
; code (e.g. burning the monitor into an EPROM on a board
; like the 88-2SIOJP), all mutable state is kept out of the
; BIOS_BASE..CODE_END code range and placed in a separate RAM
; segment at DATA_BASE instead - see the "Mutable Data
; Segment" section near the end of this file.
;
; Required assembler defines:
;   -dBIOS_BASE=xxxx    Monitor load address
;   -dDATA_BASE=xxxx    Mutable data segment address (used
;                       only when BIOS_BASE > 0)
;   -dSTACK_TOP=xxxx    Stack pointer initial value
;   -dMEMTOP=xxxx       Top of physical RAM
;   -dMEM_SIZE=xx       Memory size in KB
;
; Optional defines:
;   -dVIDEO_BASE=xxxx   Video framebuffer address
;   -dVIDEO_COLS=xx     Video columns
;   -dVIDEO_ROWS=xx     Video rows
;   -dSIM_STUB=1        Simulator-only entry stub (see below)
;========================================================

;========================================================
; Simulator-only entry stub
;========================================================
; Real hardware with a reset-vector redirect (e.g. the
; 88-2SIOJP's "Jump-Start" feature) forces execution to
; BIOS_BASE on reset without needing any code at 0000H.
; cpmsim has no such feature and always starts at PC=0000H,
; so when testing a relocated (BIOS_BASE > 0) build under the
; simulator, this stub gives it something valid to land on.
; It is NOT part of the ROM image - do not define SIM_STUB
; when building for real hardware.
;========================================================
        IFNDEF SIM_STUB
SIM_STUB        EQU     0
        ENDIF

        IF SIM_STUB
        ORG     0000H
        JMP     BOOT
        ENDIF

;========================================================
; Derived memory-layout constants
;========================================================
; These must be defined here, before first use: IF directives
; are evaluated on pass 1, so they cannot forward-reference a
; symbol (unlike instruction operands, which can).
;
; ROM_END - first address above the monitor's ROM window.
;   Wraps to 0 when the window ends exactly at the top of the
;   address space (e.g. BIOS_BASE=0E000H with an 8K ROM). The
;   code below tests it for that: 0 means "no RAM above the ROM".
; VID_END - first address above the video framebuffer. Assumes
;   the framebuffer is a whole number of 256-byte pages (true
;   for the VDM-1's 64x16 = 1024 bytes). Derived from
;   VIDEO_COLS/VIDEO_ROWS rather than video.asm's VIDEO_SIZE,
;   which is not defined until that file is INCLUDEd far below.
;========================================================
ROM_END         EQU     BIOS_BASE+ROM_SIZE

        IF VIDEO_BASE
VID_END         EQU     VIDEO_BASE+(VIDEO_COLS*VIDEO_ROWS)
        ENDIF

        ORG     BIOS_BASE

;========================================================
; BIOS Jump Table (for external programs and hardware reset)
;========================================================
; Fixed entry points at BIOS_BASE+0, +3, +6, +9, +12.
; Only assembled when BIOS_BASE > 0 (traditional layout).
;
; BJMP_BOOT at BIOS_BASE+0 is required by boards with a
; hardware reset-vector redirect (e.g. the 88-2SIOJP's
; "Jump-Start" feature), which forces a JMP to BIOS_BASE on
; reset instead of relying on code at address 0000H. It must
; always be a full cold-boot entry, not the lighter WBOOT
; path, so that serial/video hardware is initialized on a
; real power-on reset.
;========================================================
        IF BIOS_BASE
BJMP_BOOT:      JMP     BOOT            ; BIOS_BASE+0  (hardware reset entry)
BJMP_WBOOT:     JMP     WBOOT           ; BIOS_BASE+3
BJMP_CONST:     JMP     CONST           ; BIOS_BASE+6
BJMP_GETCHAR:   JMP     GETCHAR         ; BIOS_BASE+9
BJMP_PUTCHAR:   JMP     PUTCHAR         ; BIOS_BASE+12
        ENDIF

;========================================================
; ASCII Constants
;========================================================
CR              EQU     0DH
LF              EQU     0AH

;========================================================
; Cold Boot
;========================================================
BOOT:
        DI                      ; Disable interrupts
        LXI     SP,STACK_TOP    ; Initialize stack pointer

        ; Pre-serial video heartbeat: show SIO config on screen
        ; before touching serial (which may hang if misconfigured).
        ; Writes directly to VDM-1 framebuffer - no driver needed.
        IF VIDEO_BASE
        XRA     A
        OUT     VIDEO_CTRL      ; Initialize VDM-1 control register
        ; Clear first line so heartbeat text is readable
        LXI     H,VIDEO_BASE
        MVI     C,VIDEO_COLS
VHBCLR: MVI     M,' '
        INX     H
        DCR     C
        JNZ     VHBCLR
        LXI     H,VIDEO_BASE    ; HL = framebuffer write pointer
        LXI     D,MSG_VHB_SIO
        CALL    VRAW_STR
        MVI     A,SIO_DATA
        CALL    VRAW_HEX
        MVI     M,'/'
        INX     H
        MVI     A,SIO_STATUS
        CALL    VRAW_HEX
        LXI     D,MSG_VHB_RX
        CALL    VRAW_STR
        MVI     A,SIO_RX_MASK
        CALL    VRAW_HEX
        LXI     D,MSG_VHB_TX
        CALL    VRAW_STR
        MVI     A,SIO_TX_MASK
        CALL    VRAW_HEX
        IF SIO_8251
        LXI     D,MSG_VHB_8251
        CALL    VRAW_STR
        ENDIF
        IF SIO_6850
        LXI     D,MSG_VHB_6850
        CALL    VRAW_STR
        ENDIF
        ENDIF

        ; Initialize serial port (8251 if SIO_8251, 6850 if SIO_6850)
        CALL    SIO_INIT

        ; Detect memory (serial only - video not yet initialized)
        LXI     H,MSG_SCAN
        CALL    PRMSG
        CALL    MEMPROBE
        IF BIOS_BASE
        XCHG                    ; HL = free-page count (see MEMPROBE)
        ENDIF
        SHLD    DETECTED_MEM
        LXI     H,MSG_CRLF
        CALL    PRMSG

        ; Print memory size (serial only)
        CALL    PRMSIZ

        IF VIDEO_BASE
        ; Initialize video display
        CALL    V_INIT
        ENDIF

        ; System banner: version + serial config (dual output)
        CALL    PRINT_BANNER

        IF VIDEO_BASE
        LXI     H,MSG_VIDEO
        CALL    PRINTS          ; Both outputs: video info
        LXI     H,VIDEO_BASE    ; print the configured base, not a
        CALL    PRHEX16         ; hardcoded one that goes stale
        CALL    PRCRLF
        ENDIF

        ; Set up Page Zero (only when monitor is not at address 0)
        IF BIOS_BASE
        CALL    INIT_PAGE0
        ENDIF

        ; Print memory map
        CALL    PRMMAP

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
        STA     0000H
        LXI     H,WBOOT
        SHLD    0001H
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
        CALL    V_PUTCH         ; Video output
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
; Probes upward in 256-byte pages, skipping over the
; monitor's own ROM/code window [BIOS_BASE,CODE_END) when
; BIOS_BASE > 0, so free RAM can be detected on either side
; of a ROM-resident monitor (not just above it).
; Prints '*' for each 4KB found.
; Output: HL = first invalid address (MEMTOP)
;         DE = total free pages found (256 bytes/page) - used
;              instead of HL by callers when BIOS_BASE > 0,
;              since HL's stopping address no longer equals
;              "total RAM from zero" once a ROM window is
;              skipped mid-scan.
; Destroys: A, B, C, H, L
;========================================================
MEMPROBE:
        IF BIOS_BASE
        ; ROM-capable layout: probe from first page after the
        ; mutable data segment (below the monitor's ROM window)
        LXI     H,DATA_END
        ELSE
        ; Load-at-zero: probe from first page after monitor code
        LXI     H,CODE_END
        ENDIF
        MOV     A,L
        ORA     A
        JZ      MPR_AL          ; Already page-aligned
        INR     H               ; Round up to next 256-byte page
        MVI     L,0
MPR_AL:
        MVI     C,0             ; Page counter (mod 16, for '*' progress)
        LXI     D,0             ; Free-page counter (total)
MPRBLP:
        MOV     A,H
        ORA     A               ; H=0 means wrapped past 64KB
        JZ      MPRBDN

        IF BIOS_BASE
        ; Skip the whole ROM window, not just up to CODE_END: the
        ; monitor's code usually fills only part of the physical
        ; ROM/EPROM, but the rest of that window is still ROM, so
        ; probing it would fail and (before this) abort the scan
        ; early - losing every RAM page above the ROM.
        CPI     BIOS_BASE / 256
        JC      MPRBVC          ; below the ROM window - continue
        IF ROM_END
        CPI     ROM_END / 256
        JNC     MPRBVC          ; at/past the ROM window - continue
        MVI     H,ROM_END / 256 ; skip past the ROM window
        MVI     L,0
        JMP     MPRBLP
        ELSE
        ; The ROM window ends at the top of the address space,
        ; so there is nothing above it to find.
        JMP     MPRBDN
        ENDIF
MPRBVC:
        ENDIF

        IF VIDEO_BASE
        ; Step over the video framebuffer and keep scanning
        ; rather than stopping: RAM can exist above it (e.g.
        ; between the framebuffer and a ROM window higher up),
        ; and stopping here would hide all of it. Never probe
        ; the framebuffer itself - that would corrupt the display.
        CPI     VIDEO_BASE / 256
        JC      MPRBVV          ; below the framebuffer - continue
        IF VID_END
        CPI     VID_END / 256
        JNC     MPRBVV          ; at/past the framebuffer - continue
        MVI     H,VID_END / 256 ; skip past the framebuffer
        MVI     L,0
        JMP     MPRBLP
        ELSE
        JMP     MPRBDN          ; framebuffer ends at top of memory
        ENDIF
MPRBVV:
        ENDIF

        MOV     A,M             ; Read current value
        MOV     B,A             ; Save
        CMA                     ; Complement
        MOV     M,A             ; Write complement
        CMP     M               ; Read back
        MOV     M,B             ; Restore original
        JNZ     MPRBDN          ; No match = no RAM

        INX     D               ; Count this page as free RAM

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
        IF BIOS_BASE
        ; DETECTED_MEM = free-page count (0-256). KB = count/4.
        MOV     A,H
        ORA     A
        JZ      PMSZ1
        MVI     A,64            ; H<>0 means count=256 -> 64KB
        JMP     PMSZ2
PMSZ1:
        MOV     A,L
        RRC
        RRC
        ANI     03FH
        ELSE
        ; DETECTED_MEM = top-of-RAM address. KB = high byte/4.
        MOV     A,H
        ORA     A
        JNZ     PMSZ1
        MVI     A,64
        JMP     PMSZ2
PMSZ1:
        RRC
        RRC
        ANI     03FH
        ENDIF
PMSZ2:
        CALL    PRDEC
        LXI     H,MSG_KB
        CALL    PRMSG
        RET

;========================================================
; PRRANGE - Print "  <start>-<end>"
;========================================================
; Input:  HL = start address, DE = end address (inclusive)
; Destroys: A, C, D, E, H, L
;
; The end address is kept on the stack rather than in DE
; because PUTCHAR does not preserve DE when video is enabled
; (V_PUTCH destroys it).
;========================================================
PRRANGE:
        PUSH    D               ; end
        PUSH    H               ; start
        LXI     H,MSG_MAP_2SP
        CALL    PRINTS
        POP     H               ; start
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        POP     H               ; end
        CALL    PRHEX16
        RET

;========================================================
; PRMMAP - Print memory map
;========================================================
; Walks the address space in ascending order, emitting one
; line per region. Every boundary is an assemble-time
; constant, so the conditionals below pick the right ordering
; for the configured layout rather than computing it at run
; time.
;
; The ROM-capable layout (BIOS_BASE > 0) places the ROM window
; anywhere legal, so the framebuffer may fall either below it
; (the config.mk.rom case: video CC00, ROM E000) or above it.
; Those two cases need different orderings, and free RAM must
; be split around whichever regions sit inside it - reporting
; one span from DATA_END to BIOS_BASE-1 would wrongly swallow
; a framebuffer sitting in the middle of it.
;========================================================
PRMMAP:
        IF BIOS_BASE

        LXI     H,MSG_MAP_PZ
        CALL    PRINTS

        ; Monitor Data (RAM): DATA_BASE..DATA_END-1
        LXI     H,DATA_BASE
        LXI     D,DATA_END-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_DAT
        CALL    PRINTS

        IF VIDEO_BASE
        IF VIDEO_BASE < BIOS_BASE

        ; --- framebuffer below the ROM window ---
        ; Free RAM: DATA_END..VIDEO_BASE-1
        LXI     H,DATA_END
        LXI     D,VIDEO_BASE-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_RAM
        CALL    PRINTS

        ; Video: VIDEO_BASE..VID_END-1
        LXI     H,VIDEO_BASE
        LXI     D,VID_END-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_VID
        CALL    PRINTS

        IF VID_END < BIOS_BASE
        ; Free RAM between the framebuffer and the ROM window
        LXI     H,VID_END
        LXI     D,BIOS_BASE-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_RAM
        CALL    PRINTS
        ENDIF

        ; Monitor: BIOS_BASE..CODE_END-1
        LXI     H,BIOS_BASE
        LXI     D,CODE_END-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_MON
        CALL    PRINTS

        IF ROM_END
        ; Free RAM above the ROM window. Starts at ROM_END, not
        ; CODE_END - the slack between CODE_END and the end of
        ; the ROM window is still ROM, so calling it free RAM
        ; would be a lie (and MEMPROBE rightly skips it).
        LXI     H,ROM_END
        LXI     D,MEMTOP-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_RAM
        CALL    PRINTS
        ENDIF

        ELSE

        ; --- framebuffer above the ROM window ---
        LXI     H,DATA_END
        LXI     D,BIOS_BASE-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_RAM
        CALL    PRINTS

        LXI     H,BIOS_BASE
        LXI     D,CODE_END-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_MON
        CALL    PRINTS

        IF ROM_END
        LXI     H,ROM_END
        LXI     D,VIDEO_BASE-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_RAM
        CALL    PRINTS
        ENDIF

        LXI     H,VIDEO_BASE
        LXI     D,VID_END-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_VID
        CALL    PRINTS

        ENDIF
        ELSE

        ; --- no video ---
        LXI     H,DATA_END
        LXI     D,BIOS_BASE-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_RAM
        CALL    PRINTS

        LXI     H,BIOS_BASE
        LXI     D,CODE_END-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_MON
        CALL    PRINTS

        IF ROM_END
        LXI     H,ROM_END
        LXI     D,MEMTOP-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_RAM
        CALL    PRINTS
        ENDIF

        ENDIF

        ELSE

        ; --- load-at-zero: Monitor, Free RAM, [Video] ---
        LXI     H,0000H
        LXI     D,CODE_END-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_MON
        CALL    PRINTS

        LXI     H,CODE_END
        LXI     D,MEMTOP-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_RAM
        CALL    PRINTS

        IF VIDEO_BASE
        LXI     H,VIDEO_BASE
        LXI     D,VID_END-1
        CALL    PRRANGE
        LXI     H,MSG_MAP_VID
        CALL    PRINTS
        ENDIF

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
; VRAW_STR - Copy string to framebuffer (no driver needed)
;========================================================
; Used for pre-serial heartbeat before video driver init.
; Input:  DE = null-terminated string, HL = framebuffer ptr
; Output: HL advanced past written chars
; Destroys: A, D, E
;========================================================
        IF VIDEO_BASE
VRAW_STR:
        LDAX    D
        ORA     A
        RZ
        MOV     M,A
        INX     H
        INX     D
        JMP     VRAW_STR

;========================================================
; VRAW_HEX - Write byte as two hex digits to framebuffer
;========================================================
; Input:  A = byte, HL = framebuffer ptr
; Output: HL advanced by 2
; Destroys: A
;========================================================
VRAW_HEX:
        PUSH    PSW
        RRC
        RRC
        RRC
        RRC
        CALL    VRAW_NIB
        POP     PSW
VRAW_NIB:
        ANI     0FH
        ADI     '0'
        CPI     '9'+1
        JC      VRAWN1
        ADI     'A'-'9'-1
VRAWN1:
        MOV     M,A
        INX     H
        RET
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
; Optional module defaults
;========================================================
        IFNDEF ENABLE_TERM
ENABLE_TERM     EQU     0
        ENDIF

        IFNDEF ENABLE_FWUPDATE
ENABLE_FWUPDATE EQU     0
        ENDIF

;========================================================
; Include sub-modules
;========================================================
        IF BIOS_BASE
        ; video.asm's cursor variables are declared in the
        ; mutable data segment below instead (ROM-capable build).
VIDEO_VARS_EXTERNAL     EQU     1
        ENDIF
        INCLUDE serial.asm
        INCLUDE video.asm
        INCLUDE ../lib/print.asm
        INCLUDE ../lib/banner.asm
        INCLUDE ../lib/string.asm
        INCLUDE ../monitor.asm
        INCLUDE ../cmd/term.asm
        INCLUDE ../cmd/fwupdate.asm

;========================================================
; Boot Messages
;========================================================
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
        DB      'Video: VDM-1 64x16 at ',0      ; address printed by BOOT
        ENDIF

; Memory map fragments (addresses printed dynamically)
        IF BIOS_BASE
MSG_MAP_PZ:
        DB      '  0000-00FF  Page Zero',CR,LF,0
MSG_MAP_DAT:
        DB      '  Monitor Data',CR,LF,0
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

; Pre-serial heartbeat messages (raw framebuffer, no CRLF)
        IF VIDEO_BASE
MSG_VHB_SIO:
        DB      'JX SIO ',0
MSG_VHB_RX:
        DB      ' RX=',0
MSG_VHB_TX:
        DB      ' TX=',0
        IF SIO_8251
MSG_VHB_8251:
        DB      ' 8251',0
        ENDIF
        IF SIO_6850
MSG_VHB_6850:
        DB      ' 6850',0
        ENDIF
        ENDIF

;========================================================
; CODE_END / Mutable Data Segment
;========================================================
; When BIOS_BASE > 0, the monitor's code above may be
; ROM-resident (e.g. burned into an EPROM), so all mutable
; state is relocated to a separate RAM segment at DATA_BASE
; instead of being interleaved with code. CODE_END marks the
; end of ROM-resident code; DATA_END marks the end of the
; RAM variable segment. Both are used by MEMPROBE/PRMMAP to
; exclude these ranges when reporting free RAM.
;
; When BIOS_BASE = 0 (load-at-zero), there is no ROM/RAM
; split - the whole image is one RAM-resident blob, so
; variables stay right where they fall in the code stream
; and CODE_END marks the end of code+data combined, exactly
; as before.
;========================================================
        IF BIOS_BASE
CODE_END:
        ORG     DATA_BASE
        ENDIF

; These RESERVE space (DS) rather than emitting initialized
; bytes (DW 0 / DB 0). That matters for a ROM build: DW/DB
; would put 35 bytes of zeros for this RAM segment into the
; output image, so a `make hex` ROM image would carry stray
; records at DATA_BASE far below BIOS_BASE - which bloats the
; image's address span and is meaningless in an EPROM anyway.
; With DS, a ROM image contains only the BIOS_BASE..CODE_END
; code. Nothing relies on these starting zeroed: BOOT sets
; DETECTED_MEM after MEMPROBE, V_INIT zeroes the cursor pair,
; DO_LOAD zeroes LD_BCNT/LD_ECNT, FW_UPLOAD initializes the
; FW_* counters, and every command writes its own state
; before reading it.
DETECTED_MEM:   DS      2       ; Detected memory top
        IF BIOS_BASE
        ; When BIOS_BASE = 0, video.asm declares these itself
        ; (VIDEO_VARS_EXTERNAL is not set - see its INCLUDE above).
V_CURROW:       DS      1       ; Video cursor row (0-15)
V_CURCOL:       DS      1       ; Video cursor column (0-63)
        ENDIF
CMDPTR:         DS      2       ; Pointer to command string
ARGPTR:         DS      2       ; Pointer to arguments
DMP_ADDR:       DS      2       ; Dump current address
DMP_END:        DS      2       ; Dump end address
TST_SADR:       DS      2       ; Test start address
TST_EADR:       DS      2       ; Test end address
TST_CADR:       DS      2       ; Test current address
TST_ECNT:       DS      2       ; Test error count
WRT_ADDR:       DS      2       ; Write current address
LD_PORT:        DS      1       ; 0=port1 (console), 1=port2 (aux)
LD_BCNT:        DS      2       ; Total bytes loaded
LD_ECNT:        DS      2       ; Checksum error count
        IF ENABLE_FWUPDATE
FW_MIN_ADDR:    DS      2       ; Firmware upload: lowest address seen
FW_MAX_ADDR:    DS      2       ; Firmware upload: highest record-end address seen
FW_CKSUM:       DS      2       ; Firmware upload: running 16-bit checksum
FW_TMP:         DS      2       ; Firmware upload: scratch (bounds checks)
        ENDIF
CMDBUF:         DS      CMDBUF_SIZE     ; Command input buffer
; IO_TRAMP holds a three-byte "IN/OUT <port> ; RET" built at
; runtime by the monitor's in/out commands. The 8080 takes the
; port as an immediate byte, so an arbitrary runtime port has
; to be written into the instruction - and on a ROM build the
; instruction cannot live with the code. DO_IN/DO_OUT write all
; three bytes before every CALL, so it needs no initialization.
IO_TRAMP:       DS      3       ; IN/OUT <port> ; RET (built at runtime)
DATA_END:

        IF BIOS_BASE
        ELSE
CODE_END:
        ENDIF

;========================================================
        END
;========================================================
