;========================================================
; JX Monitor - Floppy Disk Boot Module
;========================================================
; Boots drive 0 of a MITS 88-DCDD (8") or 88-MDS (5.25"
; minidisk) controller: loads the disk's boot file into
; memory starting at 0000H and jumps to it.
;
; Usage: b (or boot)
;
; Derived from CDBL 3.00 - the Combo Disk Boot Loader by
; Martin Eberhard and Mike Douglas (2014-2016). The sector
; read engine, the 2:1 interleave walk, the 16-retry
; checksum recovery and the write-verify are CDBL's,
; transcribed byte-for-byte from the published listing and
; verified against its 256-byte reference image before
; being adapted here.
;
; Three things differ from stock CDBL:
;
;   1. CDBL re-initializes a 6850 ACIA at port 10H and a
;      4PIO at 20H-23H. Those are dropped - JX has already
;      brought up its own console via SIO_INIT, and writing
;      a hardcoded 6850 init would silently kill the
;      console on an 8251 machine.
;
;   2. CDBL's error exit hangs forever spraying the error
;      code at four different serial ports. Here it prints
;      one line on the configured console and cold-starts
;      the monitor (or halts, on a load-at-zero build).
;
;   3. CDBL's drive-ready wait, track-0 seek and disk-type
;      detection loop forever by design - correct for a
;      boot PROM, wrong for a monitor command, which must
;      be able to give the prompt back. Each is bounded by
;      a retry count and abortable with ESC. See the
;      timing note on BT_CKDSK below: the bounds are added
;      in a way that keeps every sector-pulse poll inside
;      the 30 us -SVALID window.
;
; Requires: DISK_BASE, BOOT_RAM_BASE
; Conditional: Only assembled when ENABLE_DISKBOOT=1
;========================================================

        IF ENABLE_DISKBOOT

        IFNDEF DISK_BASE
DISK_BASE       EQU     08H
        ENDIF

        IFNDEF BOOT_RAM_BASE
BOOT_RAM_BASE   EQU     04C00H
        ENDIF

;--------------------------------------------------------
; 88-DCDD / 88-MDS controller ports. Both controllers use
; the same three-port interface. See
; .claude/skills/88-DCDD.skill.md - most status bits are
; ACTIVE LOW (0 = condition true).
;--------------------------------------------------------
DSK_STAT        EQU     DISK_BASE       ; R: status   W: drive select
DSK_CTRL        EQU     DISK_BASE+1     ; R: sector position  W: command
DSK_DATA        EQU     DISK_BASE+2     ; R/W: data

; Drive select (write to DSK_STAT)
DDISBL          EQU     80H             ; disable/deselect all drives

; Status bits (read from DSK_STAT) - all active low
DENWD           EQU     01H             ; -Enter Write Data
DMVHD           EQU     02H             ; -Move Head OK
DHDST           EQU     04H             ; -Head Status
DRVRDY          EQU     08H             ; -Drive Ready
DTRK0           EQU     40H             ; -Track 0 detected
DNRDA           EQU     80H             ; -New Read Data Available

; Commands (write to DSK_CTRL)
STEPIN          EQU     01H             ; step in one track
STPOUT          EQU     02H             ; step out one track
HDLOAD          EQU     04H             ; 8": load head.  Minidisk: restart
                                        ; the 6.4 second motor timer

; Sector position (read from DSK_CTRL)
SVALID          EQU     01H             ; sector valid (low for first 30 us
                                        ; of the sector pulse)
SECMSK          EQU     3EH             ; sector number bits

;--------------------------------------------------------
; Disk geometry. This code assumes an 8" disk has exactly
; twice a minidisk's sectors per track, which is how the
; type detection below can work at all.
;--------------------------------------------------------
BPS             EQU     128             ; data bytes per sector
MDSPT           EQU     16              ; minidisk sectors per track
HDRSIZ          EQU     3               ; header bytes before the data
TLRSIZ          EQU     2               ; trailer bytes read after the data
SECSIZ          EQU     BPS+HDRSIZ+TLRSIZ
RETRYS          EQU     16              ; read retries per sector

;--------------------------------------------------------
; RAM layout for the relocated load engine.
;
; Three constraints are baked into the engine's tightest
; code and must hold for any BOOT_RAM_BASE:
;
;   1. BOOT_RAM_BASE's low byte is 0 (page aligned).
;   2. BOOT_SECBUF's LAST byte is at XXFF. BT_DATLUP ends
;      its 133-byte read when INR E wraps to zero - that
;      is what keeps the read loop inside the 32 us per
;      byte the controller allows.
;   3. The LSB of BOOT_RAM_BASE's high byte is 0, so
;      BT_RDSECT's overlay check can cover both pages with
;      a single compare (XRA D / ANI 0FEH).
;
; With the default 04C00H:
;   4C00..4Cxx  relocated engine
;   ....4D7A    stack, growing down from the buffer
;   4D7B..4DFF  sector buffer, last byte at 4DFF
;--------------------------------------------------------
BOOT_SECBUF     EQU     BOOT_RAM_BASE+512-SECSIZ
BOOT_STACK      EQU     BOOT_SECBUF     ; grows down from here
BT_SFSIZE       EQU     BOOT_SECBUF+1   ; file size, from the sector header
BT_SDATA        EQU     BOOT_SECBUF+HDRSIZ
DMAADR          EQU     0               ; load and execution address

; Single-character error codes, as CDBL reports them
CERMSG          EQU     'C'             ; checksum / marker byte
MERMSG          EQU     'M'             ; memory write-verify
OERMSG          EQU     'O'             ; memory overlay

;========================================================
; DO_BOOT - Boot from floppy drive 0
;========================================================
DO_BOOT:
        LXI     H,MSG_BOOTG
        CALL    PRINTS
        DI

;--------------------------------------------------------
; Select drive 0 and wait for a diskette. Do this first so
; the disk has time to settle. A minidisk always reports
; ready; it will instead stall in the type detection below
; until a few seconds after a disk is inserted.
;
; Not timing critical, and the first place a missing
; controller or an empty drive shows up - a floating bus
; reads FFH, which is "not ready" forever.
;--------------------------------------------------------
        LXI     D,0             ; 65536 polls, roughly 2.5 seconds
BT_WTEN:
        XRA     A               ; drive 0, bit 7 clear = enable
        OUT     DSK_STAT
        IN      DSK_STAT
        ANI     DRVRDY          ; diskette in drive? (0 = yes)
        JZ      BT_RDY
        CALL    BT_TICK
        JNC     BT_WTEN
        JMP     BT_NODSK

BT_RDY:
        MVI     A,HDLOAD        ; load the 8" head, or start the
        OUT     DSK_CTRL        ; minidisk's 6.4 second timer

;--------------------------------------------------------
; Step in once, then step out until track 0 is detected.
; The step-in first forces a direction change, which makes
; the delay below a >=43 ms one - the 8" drive's minimum
; for reversing.
;--------------------------------------------------------
        LXI     B,20000/12      ; 20 ms delay on the first pass only
        MVI     A,STEPIN
        LXI     D,200           ; more steps than any drive has tracks
BT_SKTR0:
        OUT     DSK_CTRL        ; issue the step
BT_DLY:
        DCX     B               ; (5)
        MOV     A,B             ; (5)
        ORA     C               ; (4)
        JNZ     BT_DLY          ; (10) 12 us per pass
        INR     C               ; from here on this loop runs once

        ; Wait for the servo to settle before looking at
        ; TRACK0 - the bit is not meaningful while the head
        ; is in motion. Separately bounded: a controller
        ; that never clears -MVHEAD would hang here.
        LXI     H,0
BT_WSTEP:
        IN      DSK_STAT
        RRC                     ; put -MVHEAD in carry
        RRC
        JNC     BT_STEPD        ; servo stable
        DCX     H
        MOV     A,H
        ORA     L
        JNZ     BT_WSTEP
        JMP     BT_DERR

BT_STEPD:
        ANI     DTRK0/4         ; A was rotated twice - so is the mask
        JZ      BT_ATTR0        ; at track 0
        CALL    BT_TICK         ; destroys A, hence the MVI below
        JC      BT_DERR
        MVI     A,STPOUT
        JMP     BT_SKTR0

;--------------------------------------------------------
; BT_CKDSK - 8" disk or minidisk?
;
; An 8" disk has sectors 0-1Fh, a minidisk 0-0Fh. Wait for
; sector 0Fh, let it pass, then read the next sector
; number: 0 on a minidisk, 10h on an 8" disk. Adding MDSPT
; turns either into that disk's sectors per track.
;
; TIMING: -SVALID is low for only about 30 us, so a poll
; loop here has to sample faster than that or it can step
; straight over the pulse. CDBL's loops are 34 and 24
; T-states; the DCR B / JNZ that bounds them adds 15,
; giving 49 T (24.5 us) and 39 T (19.5 us) at 2 MHz - both
; still inside the window, with the ESC and give-up checks
; pushed out to an outer loop that only runs every 256
; passes. Do not add instructions to the inner loops.
;--------------------------------------------------------
BT_ATTR0:
        LXI     D,0             ; overall budget for the hunt

        ; Hunt for the minidisk's last sector, 0Fh, while
        ; -SVALID is low.
BT_CK1:
        MVI     B,0             ; 256 inner passes per ESC check
BT_CK1A:
        IN      DSK_CTRL        ; (10)
        ANI     SECMSK+SVALID   ; (7)
        CPI     (MDSPT-1)*2     ; (7)
        JZ      BT_CK2          ; (10)
        DCR     B               ; (5)
        JNZ     BT_CK1A         ; (10)
        CALL    BT_TICK
        JNC     BT_CK1
        JMP     BT_NODSK

        ; Let that sector pass.
BT_CK2:
        MVI     B,0
BT_CK2A:
        IN      DSK_CTRL
        RRC                     ; -SVALID into carry
        JC      BT_CK3          ; pulse over
        DCR     B
        JNZ     BT_CK2A
        CALL    BT_TICK
        JNC     BT_CK2
        JMP     BT_NODSK

        ; Read the sector number that follows it.
BT_CK3:
        MVI     B,0
BT_CK3A:
        IN      DSK_CTRL        ; (10)
        RRC                     ; (4) -SVALID into carry
        JNC     BT_CK3B         ; (10) sector valid
        DCR     B               ; (5)
        JNZ     BT_CK3A         ; (10)
        CALL    BT_TICK
        JNC     BT_CK3
        JMP     BT_NODSK

BT_CK3B:
        ANI     SECMSK/2        ; A is already rotated right once
        ADI     MDSPT           ; 0 -> 10h (minidisk), 10h -> 20h (8")
        PUSH    PSW             ; sectors per track, across the copy below

;--------------------------------------------------------
; Relocate the load engine into RAM and enter it.
;
; The engine cannot run where it is assembled. On a ROM
; build it would be reading itself out of EPROM while the
; disk writes over low memory; on a load-at-zero build the
; first sector lands directly on top of the monitor. Once
; sector data starts arriving at 0000H the only code
; guaranteed to still exist is the copy at BOOT_RAM_BASE.
;
; Same mechanism as fwupdate.asm's FW_FLASH_TEMPLATE:
; every branch inside the template is written
; label+BOOT_RELOC, so the assembled bytes are already
; correct once moved and no runtime fixup is needed.
;--------------------------------------------------------
        LXI     H,BOOT_TEMPLATE
        LXI     D,BOOT_RAM_BASE
        LXI     B,BOOT_TPL_SIZE
BT_CPY:
        MOV     A,M
        STAX    D
        INX     H
        INX     D
        DCX     B
        MOV     A,B
        ORA     C
        JNZ     BT_CPY

        POP     PSW
        MOV     C,A             ; C = sectors per track
        MVI     B,0             ; B = first sector to read
        LXI     H,DMAADR        ; HL = DMA address
        JMP     BOOT_RAM_BASE

;========================================================
; BT_TICK - Bound a wait loop, and let ESC out of it
;========================================================
; Decrements DE and polls the console. Returns carry set
; when the caller should give up: either DE hit zero or the
; user pressed ESC.
;
; Input:  DE = remaining count
; Output: Carry set = abort, clear = keep waiting
; Destroys: A, DE
;========================================================
BT_TICK:
        CALL    CONST
        ORA     A
        JZ      BT_TICK1
        CALL    CONIN
        CPI     1BH             ; ESC
        STC
        RZ
BT_TICK1:
        DCX     D
        MOV     A,D
        ORA     E
        STC
        RZ                      ; count exhausted
        ORA     A               ; clear carry - keep waiting
        RET

;========================================================
; Pre-load failure exits
;========================================================
; Nothing has been written to memory yet, so these can use
; the monitor's normal output path and go back to the
; prompt. Deselect the drive on the way out so the head is
; not left loaded.
;========================================================
BT_NODSK:
        LXI     H,MSG_BOOTND
        JMP     BT_QUIT

BT_DERR:
        LXI     H,MSG_BOOTDE

BT_QUIT:
        MVI     A,DDISBL
        OUT     DSK_STAT
        CALL    PRINTS
        JMP     MONITOR

;========================================================
; BOOT_TEMPLATE - the relocated load engine
;========================================================
; Assembled here, only ever executed at BOOT_RAM_BASE.
;
; Reads the boot file a sector at a time into BOOT_SECBUF,
; verifies it, then copies the payload to its final home,
; checking every byte back as it goes. The sector header
; carries the file's byte count; when the DMA pointer
; passes it the load is done.
;
; Sectors are interleaved 2:1 - all the even sectors of a
; track, then all the odd ones, then step in and repeat.
;
; Input (set up by DO_BOOT, survives the JMP into here):
;   B  = first sector number (0)
;   C  = sectors per track for the detected disk
;   HL = DMA address (0)
;========================================================
BOOT_TEMPLATE:
; BOOT_RELOC has to be defined right after the label, not
; before it - z80asm cannot forward-reference a label from
; an EQU (unlike a JMP or CALL operand, which it can).
BOOT_RELOC      EQU     BOOT_RAM_BASE-BOOT_TEMPLATE

BT_NXTSEC:
        MVI     A,RETRYS        ; (7) retries for this sector

BT_RDSECT:
        LXI     SP,BOOT_STACK   ; (10) re-init the stack each attempt
        PUSH    PSW             ; (11) remaining retry count

        ; --- Step 1: hunt for the sector in B. Data starts
        ; arriving 250 us after -SVALID goes low, and
        ; -SVALID is low for 30 us. 35 T-states per pass.
BT_FNDSEC:
        IN      DSK_CTRL        ; (10)
        ANI     SECMSK+SVALID   ; (7)
        RRC                     ; (4) sector bits down to <4:0>
        CMP     B               ; (4) our sector, -SVALID low?
        JNZ     BT_FNDSEC+BOOT_RELOC    ; (10)

        ; --- Would this sector land on top of us? The
        ; engine and its buffer occupy two pages; one XRA
        ; and one ANI test both. Done here because there is
        ; time to spare before the data shows up.
        LXI     D,BOOT_SECBUF   ; (10)
        MOV     A,H             ; (5) DMA address, high byte
        XRA     D               ; (4) versus the engine's pages
        ANI     0FEH            ; (7) ignoring the low page bit
        MVI     A,OERMSG        ; (7)
        JZ      BT_RPTERR+BOOT_RELOC    ; (10) overlay - abort

        ; --- Set up the move, also while there is time.
        PUSH    H               ; (11) DMA address
        PUSH    B               ; (11) sector and SPT
        LXI     B,BPS           ; (10) B = checksum seed, C = move count

        ; --- Step 2: read the sector into BOOT_SECBUF. The
        ; buffer ends at XXFF so INR E wrapping is the loop
        ; terminator. Must stay well under 32 us per pass.
BT_DATLUP:
        IN      DSK_STAT        ; (10)
        RLC                     ; (4) -NRDA into carry
        JC      BT_DATLUP+BOOT_RELOC    ; (10) no data yet
        IN      DSK_DATA        ; (10)
        STAX    D               ; (7)
        INR     E               ; (5)
        JNZ     BT_DATLUP+BOOT_RELOC    ; (10)

        ; --- Step 3: move the payload to its destination,
        ; summing it and reading every byte back.
        MVI     E,BT_SDATA AND 0FFH     ; (7)
BT_MOVLUP:
        LDAX    D               ; (7)
        MOV     M,A             ; (7)
        CMP     M               ; (7) did it actually store?
        JNZ     BT_MEMERR+BOOT_RELOC    ; (10) no - bad or absent RAM
        ADD     B               ; (4)
        MOV     B,A             ; (5)
        INX     D               ; (5)
        INX     H               ; (5)
        DCR     C               ; (5)
        JNZ     BT_MOVLUP+BOOT_RELOC    ; (10)

        ; --- Step 4: marker byte must be FFh and the
        ; checksum must match, or retry the sector.
        XCHG                    ; (4) HL = trailer, DE = DMA
        MOV     C,M             ; (7) marker
        INR     C               ; (5) FFh + 1 = 0
        INX     H               ; (5)
        XRA     M               ; (7) against the computed sum
        ORA     C               ; (4) and the marker test
        POP     B               ; (10) sector and SPT
        JNZ     BT_BADSEC+BOOT_RELOC    ; (10)

        ; --- Past the file's byte count? Then we are done.
        LHLD    BT_SFSIZE       ; (16)
        XCHG                    ; (4) HL = DMA, DE = file size
        MOV     A,L             ; (4)
        SUB     E               ; (4)
        MOV     A,H             ; (4) result thrown away,
        SBB     D               ; (4) the borrow is what matters
        JNC     BT_LDDONE+BOOT_RELOC    ; (10) carry is clear at LDDONE

        ; --- Next sector, two ahead. BT_NXTSEC is pushed
        ; as a return address so the tail below can reach
        ; it with a one-byte RC/RZ/RET.
        LXI     D,BT_NXTSEC+BOOT_RELOC  ; (10)
        PUSH    D               ; (10)
        INR     B               ; (5)
        INR     B               ; (5)
        MOV     A,B             ; (5)
        CMP     C               ; (4) end of this pass?
        RC                      ; (5/11) no - next sector
        MVI     B,01H           ; first odd sector
        RZ                      ; even pass done - do the odd ones

        ; --- Track done. Step in and keep going. No need
        ; to wait for the step: getting from the last
        ; sector back to sector 0 costs a whole revolution
        ; (167 ms) and a step takes at most 40 us.
        MOV     A,B             ; STEPIN happens to be 01H
        OUT     DSK_CTRL
        DCR     B               ; back to sector 0
        RET                     ; into BT_NXTSEC

;--------------------------------------------------------
; Checksum or marker error: retry the sector if there are
; attempts left.
;   top of stack = DMA address for the failing sector
;   next         = retry count
;--------------------------------------------------------
BT_BADSEC:
        MVI     A,HDLOAD        ; restart the minidisk's motor timer
        OUT     DSK_CTRL
        POP     H               ; DMA address
        POP     PSW             ; retry count
        DCR     A
        JNZ     BT_RDSECT+BOOT_RELOC
        MVI     A,CERMSG        ; out of retries
        DB      11H             ; LXI D opcode - swallows the next two
                                ; bytes to skip BT_MEMERR

;--------------------------------------------------------
; Write-verify failure. HL = the address that would not
; hold its value.
;--------------------------------------------------------
BT_MEMERR:
        MVI     A,MERMSG

;--------------------------------------------------------
; BT_RPTERR - give up.   A = error code, HL = address
; BT_LDDONE - success.   Entered with carry clear.
;--------------------------------------------------------
BT_RPTERR:
        MOV     B,A             ; remember the code
        STC                     ; and that this is a failure
BT_LDDONE:
        MVI     A,DDISBL        ; turn the controller off either way
        OUT     DSK_STAT
        JNC     DMAADR          ; success - run what we loaded

        ; --- Error. Low memory is partly overwritten by
        ; now, so print through an inlined copy of CONOUT
        ; rather than calling PUTCHAR, whose cursor
        ; variables may no longer exist. Same reasoning as
        ; fwupdate.asm's FW_TX.
        XCHG                    ; DE = offending address
        LXI     H,BT_EMSG+BOOT_RELOC
        CALL    BT_STR+BOOT_RELOC
        MOV     C,B             ; the error letter
        CALL    BT_TX+BOOT_RELOC
        MVI     C,' '
        CALL    BT_TX+BOOT_RELOC
        MOV     A,D
        CALL    BT_HEX+BOOT_RELOC
        MOV     A,E
        CALL    BT_HEX+BOOT_RELOC
        MVI     C,0DH
        CALL    BT_TX+BOOT_RELOC
        MVI     C,0AH
        CALL    BT_TX+BOOT_RELOC

        IF BIOS_BASE
        ; The monitor is in ROM and survived, but its RAM
        ; variables did not. Enter at the cold-boot vector,
        ; which re-runs SIO_INIT, MEMPROBE, V_INIT and
        ; INIT_PAGE0 and rebuilds all of it.
        JMP     BIOS_BASE
        ELSE
        ; Load-at-zero build: the monitor was at 0000H and
        ; the disk has overwritten it. Nothing to go back
        ; to.
        HLT
        ENDIF

;--------------------------------------------------------
; BT_STR / BT_HEX / BT_TX - minimal relocated output
;--------------------------------------------------------
BT_STR:
        MOV     A,M
        ORA     A
        RZ
        MOV     C,A
        CALL    BT_TX+BOOT_RELOC
        INX     H
        JMP     BT_STR+BOOT_RELOC

BT_HEX:
        PUSH    PSW
        RRC
        RRC
        RRC
        RRC
        CALL    BT_HEX1+BOOT_RELOC
        POP     PSW
BT_HEX1:
        ANI     0FH
        ADI     '0'
        CPI     '9'+1
        JC      BT_HEX2+BOOT_RELOC
        ADI     'A'-'9'-1
BT_HEX2:
        MOV     C,A
        ; falls into BT_TX

BT_TX:
        IF SIO_TX_MASK
BT_TXW:
        IN      SIO_STATUS
        ANI     SIO_TX_MASK
        JZ      BT_TXW+BOOT_RELOC
        ENDIF
        MOV     A,C
        OUT     SIO_DATA
        RET

BT_EMSG:
        DB      0DH,0AH,'?BOOT ',0

BOOT_TPL_END:
BOOT_TPL_SIZE   EQU     BOOT_TPL_END-BOOT_TEMPLATE

;========================================================
; Disk boot messages
;========================================================
MSG_BOOTG:
        DB      'Booting drive 0...',CR,LF,0
MSG_BOOTND:
        DB      'No disk in drive 0.',CR,LF,0
MSG_BOOTDE:
        DB      'Drive not responding.',CR,LF,0

        ENDIF

;========================================================
; End of diskboot.asm
;========================================================
