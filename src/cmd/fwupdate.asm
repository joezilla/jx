;========================================================
; JX Monitor - Firmware Update Module
;========================================================
; fw <port>   (1=console, 2=auxiliary)
;
; Uploads a new Intel HEX firmware image via serial into a
; RAM staging buffer, validates it, asks for confirmation,
; then writes it into the live EEPROM the monitor is running
; from.
;
; WARNING: this is a self-reflash with no fallback bank. A
; failed or interrupted write can leave the EEPROM
; unbootable, recoverable only by reprogramming it externally
; (pull the chip, use a dedicated EEPROM programmer). Requires
; a writable EEPROM (e.g. 28C64B) in the socket - true EPROMs
; (2716/2732/2764/27128) cannot be written by this or any
; software running on the 88-2SIOJP. See
; .claude/skills/88-2SIOJP.skill.md.
;
; Only the final write (FW_COMMIT/FW_FLASH_TEMPLATE) touches
; the EEPROM. Upload/validation/confirmation run entirely
; from ROM using normal monitor routines - nothing is written
; until the user confirms.
;
; Requires: BIOS_BASE > 0, EEPROM_SIZE, FW_STAGE_BASE,
;           FW_WRITER_BASE
; Conditional: Only assembled when ENABLE_FWUPDATE=1
;========================================================

        IF ENABLE_FWUPDATE

; Byte offset from an EEPROM (BIOS_BASE-relative) address to
; its mirror in the RAM staging buffer, and back again. This
; is modular 16-bit arithmetic and works even when it "goes
; negative" (e.g. 02000H-0E000H = 04000H, and 0E000H+04000H
; wraps back to 02000H).
FW_OFFSET       EQU     FW_STAGE_BASE-BIOS_BASE

; First address above the EEPROM window. Wraps to 0 when the
; window ends at the top of the address space - the bounds
; check below tests for that.
EE_END          EQU     BIOS_BASE+EEPROM_SIZE

;========================================================
; DO_FW - Firmware update entry point
;========================================================
DO_FW:
        LHLD    ARGPTR
        MOV     A,M
        ORA     A
        JZ      FW_USE          ; No argument

        CALL    PRHX_IN
        JC      FW_USE          ; Parse error

        MOV     A,E
        CPI     1
        JZ      FW_P1
        CPI     2
        JZ      FW_P2
        JMP     FW_USE          ; Invalid port

        ; --- Port 1 (console) - selects the shared LDIN
        ; primitive's port exactly like DO_LOAD does ---
FW_P1:
        XRA     A
        STA     LD_PORT         ; 0 = console
        JMP     FW_GO

        ; --- Port 2 (auxiliary) ---
FW_P2:
        CALL    SIO2_INIT
        MVI     A,1
        STA     LD_PORT         ; 1 = aux
        JMP     FW_GO

FW_USE:
        LXI     H,MSG_FWUSE
        CALL    PRINTS
        JMP     MONITOR

FW_GO:
        LXI     H,MSG_FWWARN
        CALL    PRINTS
        LXI     H,MSG_LRDY      ; reuse DO_LOAD's "Send Intel HEX data..."
        CALL    PRINTS

        CALL    FW_UPLOAD
        JC      FW_REJECT       ; checksum or out-of-range error

        ; --- Image must start exactly at BIOS_BASE - a
        ; leading gap would mean the low end of the staging
        ; buffer is unwritten filler, not real firmware. ---
        LHLD    FW_MIN_ADDR
        LXI     D,BIOS_BASE
        MOV     A,H
        CMP     D
        JNZ     FW_GAP
        MOV     A,L
        CMP     E
        JNZ     FW_GAP

        ; --- Print summary: range, checksum ---
        LXI     H,MSG_FWSUM
        CALL    PRINTS
        LHLD    FW_MIN_ADDR
        CALL    PRHEX16
        MVI     A,'-'
        CALL    PUTCHAR
        LHLD    FW_MAX_ADDR
        CALL    PRHEX16
        CALL    PRCRLF

        LXI     H,MSG_FWCKS
        CALL    PRINTS
        LHLD    FW_CKSUM
        CALL    PRHEX16
        CALL    PRCRLF

        ; --- Entry-point sanity check (warning only) ---
        LDA     FW_STAGE_BASE
        CPI     0C3H            ; JMP opcode, matching BJMP_BOOT
        JZ      FW_EPOK
        LXI     H,MSG_FWEPW
        CALL    PRINTS
FW_EPOK:

        ; --- Confirm ---
        LXI     H,MSG_FWCONF
        CALL    PRINTS

        ; Skip any leftover CR/LF noise first - the hex file
        ; just uploaded may end with a line ending that RDHEX
        ; never had reason to consume, and its exact form
        ; (CR, LF, or both) isn't guaranteed.
FW_YNSKIP:
        CALL    GETCHAR
        CPI     0DH
        JZ      FW_YNSKIP
        CPI     0AH
        JZ      FW_YNSKIP

        MOV     B,A             ; save keypress - PRCRLF below clobbers A
        CALL    PUTCHAR         ; echo it
        CALL    PRCRLF

        ; Drain the Enter key after the y/n keypress so it
        ; doesn't leak into the next command prompt.
FW_DRAIN:
        CALL    GETCHAR
        CPI     0DH
        JNZ     FW_DRAIN

        MOV     A,B
        CPI     'y'
        JZ      FW_YES
        CPI     'Y'
        JZ      FW_YES

        LXI     H,MSG_FWABT
        CALL    PRINTS
        JMP     MONITOR

FW_YES:
        JMP     FW_COMMIT

FW_GAP:
        LXI     H,MSG_FWGAP
        CALL    PRINTS
        JMP     MONITOR

FW_REJECT:
        LXI     H,MSG_FWERR
        CALL    PRINTS
        JMP     MONITOR

;========================================================
; FW_UPLOAD - Receive Intel HEX into the staging buffer
;========================================================
; Uses the port already patched into LDST/LDDT by DO_FW
; (reuses LDIN/RDHEX/HEXNIB from the DO_LOAD loader,
; monitor.asm). Unlike DO_LOAD, which tolerates and just
; counts bad records, this aborts immediately on any
; checksum error or unrecognized record type - a firmware
; image can't be "mostly right." Records outside the EEPROM
; window ([BIOS_BASE,BIOS_BASE+EEPROM_SIZE)) are silently
; skipped rather than treated as an error: a normal `make
; hex` build for BIOS_BASE > 0 also emits records for the
; DATA_BASE range (RAM, not part of the EEPROM image), and
; skipping them lets that hex file be uploaded as-is.
; Nothing outside the staging buffer (plain RAM) is ever
; touched here.
; Output: Carry set on error. On success (clear carry),
;         FW_MIN_ADDR/FW_MAX_ADDR/FW_CKSUM are set from the
;         in-range records actually staged.
; Destroys: A, B, C, D, E, H, L
;========================================================
FW_UPLOAD:
        ; Fill the staging buffer with 0FFH (erased-EEPROM
        ; convention) so any gap in the uploaded records
        ; leaves predictable filler, not leftover RAM garbage.
        LXI     H,FW_STAGE_BASE
        LXI     B,EEPROM_SIZE
FW_UCLR:
        MVI     M,0FFH
        INX     H
        DCX     B
        MOV     A,B
        ORA     C
        JNZ     FW_UCLR

        LXI     H,0FFFFH
        SHLD    FW_MIN_ADDR
        LXI     H,0
        SHLD    FW_MAX_ADDR
        SHLD    FW_CKSUM

FW_UWAIT:
        CALL    LDIN
        CPI     ':'
        JNZ     FW_UWAIT

        CALL    RDHEX
        MOV     C,A             ; C = byte count
        MOV     B,A             ; B = running checksum

        CALL    RDHEX
        MOV     D,A             ; D = addr high
        ADD     B
        MOV     B,A

        CALL    RDHEX
        MOV     E,A             ; E = addr low
        ADD     B
        MOV     B,A

        CALL    RDHEX
        PUSH    PSW             ; TT
        ADD     B
        MOV     B,A
        POP     PSW

        CPI     01H
        JZ      FW_UEOF
        CPI     00H
        JNZ     FW_UBAD         ; only data/EOF records are valid here

        ; --- Data record: DE = record start, C = byte count ---
        MOV     A,C
        ORA     A
        JZ      FW_UCHK         ; zero-length record

        ; Stash record start (DE) so it survives the bounds
        ; checks below, which need DE as scratch.
        MOV     H,D
        MOV     L,E
        SHLD    FW_TMP

        ; Bounds check: record start >= BIOS_BASE. Records
        ; outside the EEPROM window are skipped, not treated
        ; as an error - a normal `make hex` build also emits
        ; records for the DATA_BASE range (RAM, not part of
        ; the EEPROM image), and this lets that hex file be
        ; uploaded as-is without hand-editing it first.
        LXI     H,BIOS_BASE
        CALL    FW_CMP16        ; carry if DE < HL
        JC      FW_USKIP

        ; Bounds check: last byte (start+C-1) < EE_END.
        ; Skipped entirely when EE_END is 0, i.e. the EEPROM
        ; window ends at the top of the address space (e.g.
        ; BIOS_BASE=0E000H with an 8K window: 0E000H+02000H
        ; wraps to 0). There every address at or above
        ; BIOS_BASE is in range, and comparing against the
        ; wrapped 0 would reject the whole image.
        IF EE_END
        MVI     H,0
        MOV     L,C
        DAD     D               ; HL = start + C
        DCX     H               ; HL = last byte address
        XCHG                    ; DE = last byte address
        LXI     H,EE_END
        CALL    FW_CMP16        ; carry if DE(lastbyte) < upper bound
        JNC     FW_USKIP
        ENDIF

        ; Restore record start into DE
        LHLD    FW_TMP
        XCHG                    ; DE = record start again

        ; Update FW_MIN_ADDR
        LHLD    FW_MIN_ADDR
        CALL    FW_CMP16        ; carry if DE(recstart) < FW_MIN_ADDR
        JNC     FW_UMAXCK
        MOV     H,D
        MOV     L,E
        SHLD    FW_MIN_ADDR

FW_UMAXCK:
        ; Update FW_MAX_ADDR using this record's last byte
        MVI     H,0
        MOV     L,C
        DAD     D               ; HL = start + C
        DCX     H               ; HL = last byte address
        XCHG                    ; DE = last byte address, HL = old DE (discard)
        LHLD    FW_MAX_ADDR
        CALL    FW_CMP16        ; carry if DE(lastbyte) < FW_MAX_ADDR
        JC      FW_UOFS
        MOV     H,D
        MOV     L,E
        SHLD    FW_MAX_ADDR

FW_UOFS:
        ; Recompute staging pointer: HL = record start + FW_OFFSET
        LHLD    FW_TMP          ; record start (saved above)
        XCHG                    ; DE = record start
        LXI     H,FW_OFFSET
        DAD     D               ; HL = staging target for first byte

FW_UDLUP:
        CALL    RDHEX           ; A = data byte (B,C,D,E,H,L preserved)
        MOV     E,A             ; E = raw byte value (scratch; D/E free here)
        MOV     M,A             ; write into staging buffer
        INX     H

        ; Whole-image checksum: FW_CKSUM += E (16-bit)
        PUSH    H
        LHLD    FW_CKSUM
        MOV     A,L
        ADD     E
        MOV     L,A
        JNC     FW_UCKNC
        INR     H
FW_UCKNC:
        SHLD    FW_CKSUM
        POP     H

        MOV     A,E             ; update per-record checksum
        ADD     B
        MOV     B,A

        DCR     C
        JNZ     FW_UDLUP

        ; --- Verify record checksum ---
FW_UCHK:
        CALL    RDHEX           ; trailing checksum byte
        ADD     B
        JNZ     FW_UBAD         ; sum should be 00
        JMP     FW_UWAIT

FW_UBAD:
        STC
        RET

        ; --- Out-of-range record: discard C data bytes + 1
        ; checksum byte (not verified) and continue - same
        ; discard pattern as DO_LOAD's LD_SKIP. ---
FW_USKIP:
        CALL    RDHEX
        DCR     C
        JNZ     FW_USKIP
        CALL    RDHEX           ; checksum byte, discarded
        JMP     FW_UWAIT

FW_UEOF:
        CALL    RDHEX           ; discard EOF checksum byte
        ORA     A               ; clear carry - success
        RET

;========================================================
; FW_CMP16 - Compare DE against HL (unsigned 16-bit)
;========================================================
; Output: Carry set if DE < HL, else clear
; Destroys: A
;========================================================
FW_CMP16:
        MOV     A,D
        CMP     H
        JNZ     FW_CMP16R
        MOV     A,E
        CMP     L
FW_CMP16R:
        RET

;========================================================
; FW_COMMIT - Relocate and run the flash-writer
;========================================================
; Copies FW_FLASH_TEMPLATE's bytes from ROM to
; FW_WRITER_BASE and jumps there. Everything from this
; point on executes from RAM and never calls back into the
; ROM being overwritten.
;========================================================
FW_COMMIT:
        LXI     H,FW_FLASH_TEMPLATE
        LXI     D,FW_WRITER_BASE
        LXI     B,FW_FLASH_SIZE
FW_CPYLP:
        MOV     A,M
        STAX    D
        INX     H
        INX     D
        DCX     B
        MOV     A,B
        ORA     C
        JNZ     FW_CPYLP

        ; count = FW_MAX_ADDR - BIOS_BASE + 1
        LHLD    FW_MAX_ADDR
        LXI     D,BIOS_BASE
        MOV     A,E
        CMA
        MOV     E,A
        MOV     A,D
        CMA
        MOV     D,A
        INX     D               ; DE = -BIOS_BASE (two's complement)
        DAD     D               ; HL = FW_MAX_ADDR - BIOS_BASE
        INX     H               ; HL = count
        MOV     B,H
        MOV     C,L             ; BC = count

        ; HL = destination (the EEPROM, starts at BIOS_BASE).
        ; FW_FLASH_TEMPLATE derives the source pointer from
        ; HL each iteration via FW_OFFSET, so only HL and BC
        ; need to be set up here.
        LXI     H,BIOS_BASE

        JMP     FW_WRITER_BASE  ; enter the relocated blob

;========================================================
; FW_FLASH_TEMPLATE - Self-relocating EEPROM writer
;========================================================
; ROM-resident as assembled, but only ever COPIED to
; FW_WRITER_BASE and run from there - never executed in
; place. Every internal branch is written as label+FW_RELOC
; so the assembled bytes are already correct once relocated,
; with no runtime fixup needed (verified: z80asm resolves
; label+constant expressions at assemble time).
;
; Input (set by FW_COMMIT, survives the JMP into this blob):
;   HL = destination pointer (the EEPROM, starts at BIOS_BASE).
;        The source (staging buffer) pointer is derived from
;        HL each iteration via FW_OFFSET, not passed directly.
;   BC = remaining byte count
;
; Per-byte write uses the manual's "Polled EEPROM Write
; Completion" scheme (DATA polling): write the byte, then
; repeatedly read it back until the readback matches, with a
; ~40ms bounded timeout matching the manual's own example.
; Applies to the 28C64B per Atmel's 28Cxx family-wide DATA
; polling behavior (see 88-2SIOJP.skill.md).
;
; On success: prints "OK" then JMP BIOS_BASE - mimics a
; hardware Jump-Start reset into the freshly-written image.
; On failure: prints "FAIL @<addr>" then HLT - the EEPROM may
; now be partially overwritten and unbootable; recovery
; requires an external EEPROM programmer.
;
; Status output uses FW_TX (an inlined duplicate of CONOUT's
; body, serial.asm) rather than calling the real CONOUT/
; PUTCHAR, which may by now be corrupted - same precedent as
; VRAW_STR/VRAW_HEX in bios.asm.
;========================================================
FW_FLASH_TEMPLATE:
; FW_RELOC must be defined here, right after FW_FLASH_TEMPLATE's
; label, not before it - z80asm's EQU cannot forward-reference a
; label that hasn't been defined yet (unlike JMP/JZ/CALL operands,
; which can).
FW_RELOC        EQU     FW_WRITER_BASE-FW_FLASH_TEMPLATE
FW_WLOOP:
        MOV     A,B
        ORA     C
        JZ      FW_WOK+FW_RELOC         ; count==0, done

        PUSH    B                       ; save remaining count

        PUSH    H                       ; save dest ptr
        LXI     D,FW_OFFSET
        DAD     D                       ; HL = dest + FW_OFFSET = source addr
        MOV     A,M                     ; A = source byte
        POP     H                       ; HL = dest ptr restored

        MOV     B,A                     ; B = byte to write
        MOV     M,B                     ; write to the EEPROM at dest

        LXI     D,1860                  ; ~40ms timeout (per the manual)
FW_WPOLL:
        DCX     D
        MOV     A,D
        ORA     E
        JZ      FW_WFAIL+FW_RELOC       ; timed out
        MOV     A,M                     ; read back
        CMP     B                       ; matches written value?
        JNZ     FW_WPOLL+FW_RELOC       ; not yet

        POP     B                       ; restore remaining count
        INX     H                       ; advance dest ptr
        DCX     B                       ; one byte done
        JMP     FW_WLOOP+FW_RELOC

FW_WOK:
        MVI     C,'O'
        CALL    FW_TX+FW_RELOC
        MVI     C,'K'
        CALL    FW_TX+FW_RELOC
        JMP     BIOS_BASE               ; reboot into the new image

FW_WFAIL:
        ; HL = failing address (stack left unbalanced - we
        ; never return, so it doesn't matter)
        MVI     C,'F'
        CALL    FW_TX+FW_RELOC
        MVI     C,'A'
        CALL    FW_TX+FW_RELOC
        MVI     C,'I'
        CALL    FW_TX+FW_RELOC
        MVI     C,'L'
        CALL    FW_TX+FW_RELOC
        MVI     C,' '
        CALL    FW_TX+FW_RELOC
        MOV     A,H
        CALL    FW_TXHEX+FW_RELOC
        MOV     A,L
        CALL    FW_TXHEX+FW_RELOC
        HLT

;--------------------------------------------------------
; FW_TXHEX - Print A as 2 hex digits via FW_TX
;--------------------------------------------------------
FW_TXHEX:
        PUSH    PSW
        RRC
        RRC
        RRC
        RRC
        CALL    FW_TXNIB+FW_RELOC
        POP     PSW
FW_TXNIB:
        ANI     0FH
        ADI     '0'
        CPI     '9'+1
        JC      FW_TXNIB2+FW_RELOC
        ADI     'A'-'9'-1
FW_TXNIB2:
        MOV     C,A
        CALL    FW_TX+FW_RELOC
        RET

;--------------------------------------------------------
; FW_TX - Transmit one character (in C) via the console
; port. Inlined duplicate of CONOUT (serial.asm) - does not
; call the real CONOUT, which may be corrupted by now. Only
; the console port is used here regardless of which port the
; image was uploaded from.
;--------------------------------------------------------
FW_TX:
        IF SIO_TX_MASK
FW_TXW:
        IN      SIO_STATUS
        ANI     SIO_TX_MASK
        JZ      FW_TXW+FW_RELOC
        ENDIF
        MOV     A,C
        OUT     SIO_DATA
        RET

FW_FLASH_END:
FW_FLASH_SIZE   EQU     FW_FLASH_END-FW_FLASH_TEMPLATE

        ENDIF

;========================================================
; End of fwupdate.asm
;========================================================
