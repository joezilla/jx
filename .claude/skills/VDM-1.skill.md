# SKILL: Programming the Processor Technology VDM-1 Video Display Module in 8080 Assembly

## Overview

The Processor Technology VDM-1 (Video Display Module) was the first video card for S-100 bus computers, created in 1975 by Lee Felsenstein. It provides a **memory-mapped** text display — the CPU writes ASCII characters directly into a 1 KB region of the address space, and the VDM-1 hardware continuously reads that memory and generates a composite video signal. There are no I/O ports for character output; the display is controlled entirely through memory writes and a single display parameter output port.

The VDM-1 was used in the Altair 8800, IMSAI 8080, and was integrated into Processor Technology's Sol-20 computer. It was driven by the SOLOS (Sol Operating System), CUTER (for non-Sol S-100 machines), and CONSOL monitor programs.

**Key design feature:** The VDM-1 uses **two-port memory** — electronic switches allow the display hardware and the CPU to access screen memory simultaneously without bus contention. The CPU can write to screen memory at any time without waiting for blanking periods or causing snow/glitches.

---

## Display Specifications

| Parameter | Value |
|-----------|-------|
| Display type | Monochrome text (black and white) |
| Columns | 64 characters per line |
| Rows | 16 lines |
| Total characters | 64 × 16 = 1,024 |
| Screen memory size | 1,024 bytes (1 KB) |
| Character matrix | 7 × 9 dot matrix within a larger cell |
| Character set | Full 128-character ASCII (upper, lower case, and control characters) |
| Character ROM | On-board ROM (multiple ROM versions exist with different glyphs) |
| Video output | Composite video (EIA standard), BNC or coax connector |
| Video standard | NTSC (60 Hz) or PAL (50 Hz) via jumper |
| Horizontal resolution | 576 pixels (64 chars × 9 dots/char) |

---

## Memory Map

### Screen Memory

The VDM-1's 1 KB of screen RAM is mapped into the CPU's address space. The base address is **jumper-configurable** in 1 KB increments. The standard (default) address is:

```
Base address: CC00h (default)
End address:  CFFFh (CC00h + 3FFh = 1023 bytes)
```

The screen memory occupies addresses CC00h through CFFFh when set to the default configuration.

### Screen Memory Layout

Screen memory is organized linearly: the first byte maps to the top-left character position, and bytes proceed left-to-right, top-to-bottom:

```
Address    Screen Position
───────    ─────────────────────────────────────────
CC00h      Row 0, Column 0  (top-left corner)
CC01h      Row 0, Column 1
...
CC3Fh      Row 0, Column 63 (end of first line)
CC40h      Row 1, Column 0  (start of second line)
CC41h      Row 1, Column 1
...
CC7Fh      Row 1, Column 63
CC80h      Row 2, Column 0
...
CFBFh      Row 15, Column 63 (bottom-right corner)
CFC0h-     (wraps / unused in basic addressing)
CFFFh
```

### Address Calculation

To compute the memory address for a given row and column:

```
address = BASE + (row × 64) + column
```

Where `BASE` = CC00h (default), `row` = 0–15, `column` = 0–63.

In 8080 assembly:
```asm
; Calculate screen address for row in B, column in C
; Result in HL
; Assumes BASE = CC00h
calc_addr:
    MOV  A,B          ; A = row (0-15)
    RLC               ; × 2
    RLC               ; × 4
    RLC               ; × 8
    RLC               ; × 16
    RLC               ; × 32
    RLC               ; × 64
    ; A now has row × 64 (works because row < 16, so no overflow into bit 7
    ;  for the low byte; but we need both bytes)
    
    ; Better approach using 16-bit math:
    MOV  A,B          ; A = row
    ANI  0Fh          ; Mask to 0-15
    MOV  L,A          ; L = row
    MVI  H,00h        ; HL = row
    DAD  H            ; HL = row × 2
    DAD  H            ; HL = row × 4
    DAD  H            ; HL = row × 8
    DAD  H            ; HL = row × 16
    DAD  H            ; HL = row × 32
    DAD  H            ; HL = row × 64
    MOV  A,L
    ADD  C            ; Add column
    MOV  L,A          ; HL = row*64 + col
    MVI  A,0CCh       ; High byte of base address
    ADD  H            ; Add any carry from row calc
    MOV  H,A          ; HL = CC00h + row*64 + col
    RET
```

### Configurable Base Addresses

The base address is set via jumpers on the board. Common configurations:

| Jumper Setting | Base Address | Address Range |
|---------------|-------------|---------------|
| Default | CC00h | CC00h–CFFFh |
| C000h | C000h | C000h–C3FFh |
| C400h | C400h | C400h–C7FFh |
| C800h | C800h | C800h–CBFFh |
| CC00h | CC00h | CC00h–CFFFh |
| D000h | D000h | D000h–D3FFh |
| ...etc | (1K steps) | |

**Important:** The RAM on the VDM-1 board replaces system RAM at its configured address. If you have system RAM that overlaps the VDM-1's address range, the system RAM board must be configured to NOT respond to those addresses (disable that 1K block).

---

## Character Byte Format

Each byte in screen memory represents one character position. The byte format is:

```
Bit 7: Cursor / Inverse Video flag
Bits 6-0: ASCII character code (0-127)
```

### Bit 7 — Cursor / Inverse Video

When bit 7 is SET (1), the character is displayed in **inverse video** (black character on white background instead of white on black). This is used to implement:

- **Block cursor**: Write a space (20h) with bit 7 set → A0h appears as a solid white block
- **Highlighted text**: Any character with bit 7 set appears in reverse video
- **Blinking**: If DIP switch is configured, characters with bit 7 set will blink

Setting bit 7 is done by OR-ing the ASCII code with 80h:

```asm
; Display character 'A' (41h) in normal video at current position
    MVI  A,41h        ; 'A'
    MOV  M,A          ; Write to screen memory

; Display character 'A' in inverse video (highlighted)
    MVI  A,0C1h       ; 'A' (41h) OR 80h = C1h
    MOV  M,A          ; Write to screen memory

; Display a block cursor (inverse space)
    MVI  A,0A0h       ; Space (20h) OR 80h = A0h
    MOV  M,A          ; Solid inverse block appears
```

### Bits 6-0 — Character Code

Standard 7-bit ASCII encoding. The character ROM provides glyphs for all 128 characters (codes 00h–7Fh), including:

- 20h–7Eh: Printable ASCII characters (space through tilde)
- 00h–1Fh: Control characters — displayed as **graphic symbols** (not blank)
- Some control characters have special display behavior when DIP-switch-enabled blanking is active

### Special Control Characters (Display Behavior)

When the appropriate DIP switches are set, certain control characters trigger **text blanking**:

| Character | ASCII Code | Blanking Behavior (when enabled) |
|-----------|-----------|--------------------------------|
| CR (Carriage Return) | 0Dh | Blanks all characters from this position to end of line |
| VT (Vertical Tab) | 0Bh | Blanks all characters from this position to end of screen |

The CR and VT characters themselves are displayed (as their ROM glyph), but all subsequent positions on the line (for CR) or screen (for VT) appear blank. This feature is **DIP-switch selectable** and can be disabled.

**Note:** These control characters do NOT cause cursor movement or line feeds — they are simply stored in screen memory like any other character. The display hardware interprets them for blanking purposes only. Cursor movement and text editing are handled entirely by software (SOLOS/CUTER).

---

## Display Parameter Port (I/O Port)

The VDM-1 has a single **output-only** I/O port that controls display scrolling and line offset.

### Port Address

The default I/O port address is:

| Name | Default Address | Direction |
|------|----------------|-----------|
| DSTAT | **FEh** (254 decimal) | Output only |

The port address is jumper-configurable. In the Sol-20, it is at FEh. Some configurations use C8h. The VDM-2021 reproduction defaults to C8h.

### Port Byte Format

```
Bit 7: Scroll offset bit 3 (MSB)  ┐
Bit 6: Scroll offset bit 2        │ Upper nibble: Screen start LINE
Bit 5: Scroll offset bit 1        │ (which row of screen memory appears
Bit 4: Scroll offset bit 0 (LSB)  ┘  as the first line on display)

Bit 3: Character row bit 3 (MSB)  ┐
Bit 2: Character row bit 2        │ Lower nibble: Character row offset
Bit 1: Character row bit 1        │ (which scan line of the character
Bit 0: Character row bit 0 (LSB)  ┘  cell is displayed first)
```

### Upper Nibble — Screen Line Scroll Offset (bits 7-4)

This 4-bit value (0–15) determines which row of screen memory appears as the **first visible line** on the display. This enables **hardware scrolling** without moving data in memory:

- Value 0: Row 0 (CC00h) is at the top of the screen (normal)
- Value 1: Row 1 (CC40h) is at the top, Row 0 wraps to the bottom
- Value 2: Row 2 (CC80h) is at the top, etc.
- Value N: Row N is at the top; rows wrap around

**Hardware scrolling** is dramatically faster than copying 960+ bytes of screen memory:

```asm
; Scroll the screen up by one line using hardware scroll
; Instead of moving 960 bytes, just change one I/O port value
SCROLL_POS  DB  00h      ; Current scroll offset (0-15)

scroll_up:
    LDA  SCROLL_POS    ; Get current scroll offset
    INR  A             ; Increment
    ANI  0Fh           ; Wrap at 16 (mask to 4 bits)
    STA  SCROLL_POS    ; Save new offset
    RLC                ; Shift to upper nibble
    RLC
    RLC
    RLC
    OUT  0FEh          ; Write to display parameter port
    RET
```

After scrolling, the "new" bottom line contains old data and should be cleared:

```asm
; After scroll_up, clear the new bottom line
; The new bottom line is at: BASE + (SCROLL_POS - 1) * 64
; (the line that just scrolled off the top is now at the bottom)
clear_bottom:
    LDA  SCROLL_POS
    DCR  A             ; Previous line (now at bottom)
    ANI  0Fh           ; Wrap
    ; Calculate address: BASE + line * 64
    ; ... (use calc_addr routine)
    MVI  C,40h         ; 64 characters
    MVI  A,20h         ; Space character
clr_loop:
    MOV  M,A           ; Clear position
    INX  H             ; Next position
    DCR  C
    JNZ  clr_loop
    RET
```

### Lower Nibble — Character Row Offset (bits 3-0)

This 4-bit value selects which scan line within the character cell is displayed first. In normal operation this is set to 0. Changing this value enables **smooth scrolling** — by incrementing through the scan lines (0 through 8 for a 9-line character cell), you can smoothly scroll the display one pixel row at a time before jumping to the next character line.

```asm
; Smooth scroll: increment pixel row, then jump to next line
; Assumes 9 scan lines per character (0-8)
smooth_scroll:
    LDA  PIXEL_ROW     ; Current pixel offset (0-8)
    INR  A
    CPI  09h           ; Past last scan line?
    JC   no_line_jump  ; No, just update pixel offset
    
    ; Jump to next character line
    XRA  A             ; Reset pixel row to 0
    STA  PIXEL_ROW
    CALL scroll_up     ; Advance line scroll by 1
    RET
    
no_line_jump:
    STA  PIXEL_ROW
    LDA  SCROLL_POS
    RLC
    RLC
    RLC
    RLC                ; Upper nibble = line offset
    ORA  A             ; Combine with pixel row
    LDA  PIXEL_ROW
    ; Need to combine: (SCROLL_POS << 4) | PIXEL_ROW
    MOV  B,A           ; B = pixel row
    LDA  SCROLL_POS
    RLC
    RLC
    RLC
    RLC
    ORA  B             ; Combine upper and lower nibbles
    OUT  0FEh          ; Write to display parameter port
    RET
```

**Writing 00h to the port** resets the display to normal: row 0 at the top, no pixel offset.

---

## DIP Switch Settings

The VDM-1 has a 6-position DIP switch that controls display behavior. These are hardware settings, not programmable:

| Switch | Function |
|--------|----------|
| 1 | **Normal/Inverted display**: Selects whether the entire screen shows normal (white on black) or inverted (black on white) video |
| 2 | **Cursor blink**: When ON, characters with bit 7 set will blink on and off |
| 3 | **CR blanking**: When ON, a CR character (0Dh) in screen memory blanks all characters to the right on that line |
| 4 | **VT blanking**: When ON, a VT character (0Bh) in screen memory blanks all characters below and to the right |
| 5-6 | **Interrupt vector**: Configure the interrupt vector for the optional vertical retrace interrupt (active if V.I. jumper is installed) |

---

## Programming Procedures

### 1. Clear the Screen

```asm
; Clear entire screen to spaces
; BASE = CC00h
VDMEM   EQU  0CC00h

clear_screen:
    LXI  H,VDMEM      ; Start of screen memory
    MVI  C,00h         ; 256 iterations × 4 = 1024 bytes
    MVI  A,20h         ; Space character
clr4:
    MOV  M,A           ; Clear 4 consecutive bytes
    INX  H
    MOV  M,A
    INX  H
    MOV  M,A
    INX  H
    MOV  M,A
    INX  H
    DCR  C
    JNZ  clr4
    
    XRA  A
    OUT  0FEh          ; Reset scroll to line 0, pixel row 0
    RET
```

### 2. Write a Character at Row, Column

```asm
; Write character in A at row B, column C
; Destroys HL
write_char:
    PUSH PSW           ; Save character
    ; Calculate address
    MOV  A,B           ; Row
    ANI  0Fh
    MOV  L,A
    MVI  H,00h
    DAD  H             ; ×2
    DAD  H             ; ×4
    DAD  H             ; ×8
    DAD  H             ; ×16
    DAD  H             ; ×32
    DAD  H             ; ×64
    MOV  A,C           ; Column
    ADD  L
    MOV  L,A
    MVI  A,0CCh        ; High byte of VDMEM
    ADC  H
    MOV  H,A           ; HL = screen address
    POP  PSW           ; Restore character
    MOV  M,A           ; Write to screen
    RET
```

### 3. Write a String to Screen

```asm
; Write null-terminated string at address DE to screen starting at HL
; HL = screen memory address, DE = string address
write_string:
    LDAX D             ; Get character from string
    ORA  A             ; Null terminator?
    RZ                 ; Yes, done
    MOV  M,A           ; Write to screen
    INX  H             ; Next screen position
    INX  D             ; Next string character
    JMP  write_string
```

### 4. Display a Cursor

```asm
; Show block cursor at screen address HL
; Saves the character under cursor first
CURSOR_CHAR  DB  20h   ; Character under cursor
CURSOR_ADDR  DW  0CC00h ; Current cursor address

show_cursor:
    SHLD CURSOR_ADDR   ; Save cursor position
    MOV  A,M           ; Read character at position
    STA  CURSOR_CHAR   ; Save it
    ORI  80h           ; Set bit 7 for inverse video
    MOV  M,A           ; Write back (now shows as cursor)
    RET

; Remove cursor (restore original character)
hide_cursor:
    LHLD CURSOR_ADDR   ; Get cursor position
    LDA  CURSOR_CHAR   ; Get original character
    MOV  M,A           ; Restore it
    RET
```

### 5. Software Scroll (Moving Memory)

When hardware scrolling is not used (or for partial screen scrolling), you must copy memory:

```asm
; Scroll the entire screen up one line (software method)
; Copies 960 bytes up by 64, then clears last line
soft_scroll_up:
    LXI  H,VDMEM+40h  ; Source: start of line 1
    LXI  D,VDMEM      ; Destination: start of line 0
    MVI  B,03h         ; 3 × 256 = 768 bytes
    MVI  C,00h         ; + 192 bytes (3*256 + 192 = 960)
    
    ; Copy 960 bytes (15 lines × 64 chars)
copy_loop:
    MOV  A,M           ; Read from source
    STAX D             ; Write to destination
    INX  H
    INX  D
    DCR  C
    JNZ  copy_loop
    DCR  B
    JNZ  copy_loop
    ; Copy remaining 192 bytes
    MVI  C,0C0h        ; 192
copy2:
    MOV  A,M
    STAX D
    INX  H
    INX  D
    DCR  C
    JNZ  copy2
    
    ; Clear last line
    MVI  C,40h         ; 64 chars
    MVI  A,20h         ; Space
clear_last:
    STAX D
    INX  D
    DCR  C
    JNZ  clear_last
    RET
```

### 6. Fill Screen with a Pattern (for Testing)

```asm
; Fill screen with incrementing ASCII characters
; Useful for testing the VDM-1 setup
test_pattern:
    LXI  H,VDMEM
    MVI  A,20h         ; Start with space
    MVI  C,00h         ; 256 × 4 = 1024 iterations
fill_loop:
    MOV  M,A
    INX  H
    INR  A             ; Next character
    ANI  7Fh           ; Keep in 0-127 range
    CPI  20h           ; Below space?
    JNC  fill_ok
    MVI  A,20h         ; Reset to space
fill_ok:
    MOV  M,A
    INX  H
    INR  A
    ANI  7Fh
    CPI  20h
    JNC  fill_ok2
    MVI  A,20h
fill_ok2:
    MOV  M,A
    INX  H
    INR  A
    ANI  7Fh
    CPI  20h
    JNC  fill_ok3
    MVI  A,20h
fill_ok3:
    MOV  M,A
    INX  H
    INR  A
    ANI  7Fh
    CPI  20h
    JNC  fill_ok4
    MVI  A,20h
fill_ok4:
    DCR  C
    JNZ  fill_loop
    RET
```

---

## SOLOS/CUTER VDM Driver Escape Sequences

The SOLOS and CUTER monitor programs provide a software VDM driver (VDMOT entry point) that interprets control characters and escape sequences. When writing software that uses SOLOS/CUTER, output characters through the VDMOT routine rather than directly to screen memory for proper cursor management.

### Control Characters (via VDMOT driver)

| Character | Code | Action |
|-----------|------|--------|
| Backspace | 08h | Move cursor left one position (wrap mode) |
| Line Feed | 0Ah | Move cursor down one line (wrap mode) |
| Vertical Tab | 0Bh | Move cursor up one line (wrap mode) |
| Carriage Return | 0Dh | Move cursor to beginning of current line |
| ESC | 1Bh | Start escape sequence (see below) |
| Clear Screen | (via ESC sequence) | Clear screen, home cursor |

### Escape Sequences (via VDMOT driver)

| Sequence | Action |
|----------|--------|
| ESC `*` | Clear screen; home cursor to top-left |
| ESC `=` row col | Position cursor (row and col are sent as bytes with 20h offset) |
| ESC `01` | Move cursor right one position |
| ESC `02` | Move cursor left one position |
| ESC `03` | Move cursor up one line |
| ESC `04` | Move cursor down one line |

**Cursor positioning example:**
```asm
; Position cursor to row 5, column 10 using SOLOS/CUTER
    MVI  B,1Bh        ; ESC
    CALL VDMOT
    MVI  B,'='         ; Set cursor position command
    CALL VDMOT
    MVI  B,20h+5       ; Row 5 (offset by 20h)
    CALL VDMOT
    MVI  B,20h+10      ; Column 10 (offset by 20h)
    CALL VDMOT
```

---

## System Integration: Port Assignments (Sol-20 / CUTER Standard)

When using the VDM-1 in a typical Processor Technology system with the 3P+S I/O board:

| Port | Address | Function |
|------|---------|----------|
| STAPT | FAh | General status port |
| SERST | F8h | Serial status port |
| SDATA | F9h | Serial data port |
| TDATA | FBh | Tape data port |
| KDATA | FCh | Keyboard data port |
| PDATA | FDh | Parallel data port |
| DSTAT | FEh | **VDM display parameter port** |
| SENSE | FFh | Sense switches |

### Keyboard Input (via 3P+S board)

The VDM-1 is display-only — it has no keyboard input. Keyboard input comes through a separate board, typically the Processor Technology 3P+S (3 Parallel + Serial) board.

```asm
; Read keyboard (via 3P+S board)
KDATA   EQU  0FCh      ; Keyboard data port
STAPT   EQU  0FAh      ; Status port
KDR     EQU  01h       ; Keyboard Data Ready bit mask

read_key:
    IN   STAPT         ; Read status
    ANI  KDR           ; Keyboard data ready?
    JZ   read_key      ; No, wait
    IN   KDATA         ; Read keystroke
    RET
```

---

## Important Constants (from CONSOL/SOLOS/CUTER Source)

```asm
; VDM Parameters
VDMEM   EQU  0CC00h    ; VDM screen memory base address
DSTAT   EQU  0FEh      ; VDM display parameter output port

; Screen dimensions
COLS    EQU  64         ; Characters per line
ROWS    EQU  16         ; Lines on screen
SCRNSZ  EQU  1024       ; Total screen memory (COLS × ROWS)

; Character constants
BLANK   EQU  20h       ; Space character
CR      EQU  0Dh       ; Carriage return
LF      EQU  0Ah       ; Line feed
VT      EQU  0Bh       ; Vertical tab
ESC     EQU  1Bh       ; Escape

; Cursor
CURSOR  EQU  0A0h      ; Block cursor (space with bit 7 set)

; Keyboard special keys (Sol-20 / Proc Tech keyboard)
MODE    EQU  80h       ; MODE key (Control-@)
LEFT    EQU  81h       ; Cursor left
RIGHT   EQU  93h       ; Cursor right
UP      EQU  97h       ; Cursor up
DOWN    EQU  9Ah       ; Cursor down
HOME    EQU  8Eh       ; Home
CLEAR   EQU  8Bh       ; Clear screen
BACKS   EQU  5Fh       ; Backspace (underscore key)

; I/O Ports (Processor Technology standard)
STAPT   EQU  0FAh      ; General status port
SERST   EQU  0F8h      ; Serial status port
SDATA   EQU  0F9h      ; Serial data port
TDATA   EQU  0FBh      ; Tape data port
KDATA   EQU  0FCh      ; Keyboard data port
PDATA   EQU  0FDh      ; Parallel data port
SENSE   EQU  0FFh      ; Sense switches

; Status bit masks
KDR     EQU  01h       ; Keyboard Data Ready
PDR     EQU  02h       ; Parallel Data Ready
SDR     EQU  40h       ; Serial Data Ready
STBE    EQU  80h       ; Serial Transmit Buffer Empty
```

---

## Programming Tips and Common Patterns

### 1. No Bus Contention — Write Anytime
Unlike later video systems (CGA, etc.), the VDM-1's two-port memory means you can write to screen memory at any time without causing display glitches. Take advantage of this for smooth animations.

### 2. Hardware Scroll is Much Faster Than Software Scroll
Changing one byte on the display parameter port scrolls the entire screen instantly. Use hardware scrolling whenever possible. Only use software (memory copy) scrolling when you need partial screen scrolls or split-screen effects.

### 3. Inverse Video for Visual Effects
Bit 7 gives you a simple but effective tool for highlighting, cursors, and visual emphasis. You can create "selected" menu items, highlight search results, or flash warnings by toggling bit 7.

### 4. The Display Parameter Port is Write-Only
You cannot read back the current scroll position from the port. Your software must track the current scroll offset in a RAM variable.

### 5. Address Wrapping
Screen memory wraps around within the 1 KB block. When using hardware scrolling, the "bottom" of the logical screen may physically precede the "top" in memory. Your cursor positioning and string output routines must handle this wrap-around.

```asm
; Wrap screen address within the 1K block
; HL = potential address that might exceed CFFFh
wrap_addr:
    MOV  A,H
    CPI  0D0h          ; Past CFFFh? (for CC00h base)
    RC                  ; No, address is fine
    SUI  04h           ; Subtract 1K (0400h) from high byte
    MOV  H,A           ; Wrapped back into CC00-CFFF range
    RET
```

### 6. Character ROM Variations
Multiple versions of the character ROM were shipped. The user cannot know which version they will receive. Do not rely on specific glyph shapes for control characters (00h–1Fh). Printable ASCII (20h–7Eh) is consistent across versions.

### 7. Screen Memory Conflicts
The VDM-1 occupies 1 KB of the CPU address space. System RAM boards must be configured to NOT respond to the VDM-1's address range. Failure to do so causes bus conflicts and garbled display. When setting up a new system, always verify that the RAM board's address decoding excludes the VDM-1 range.

### 8. Writing Assembly for Direct Screen Access
For games and fast-updating programs, bypass the SOLOS/CUTER driver and write directly to screen memory. This is much faster than calling VDMOT for each character:

```asm
; Fast screen write: display "HELLO" at row 0, col 0
    LXI  H,VDMEM       ; Top-left
    MVI  M,'H'
    INX  H
    MVI  M,'E'
    INX  H
    MVI  M,'L'
    INX  H
    MVI  M,'L'
    INX  H
    MVI  M,'O'
```

---

## Complete Example: Simple Message Display

```asm
; Display "HELLO WORLD" centered on screen with cursor blinking
; Standalone program — no SOLOS/CUTER dependency

VDMEM   EQU  0CC00h
DSTAT   EQU  0FEh

        ORG  0100h      ; Or wherever your code loads

START:
        ; Reset display parameter port
        XRA  A
        OUT  DSTAT

        ; Clear screen
        LXI  H,VDMEM
        MVI  B,04h      ; 4 × 256 = 1024
        MVI  A,20h      ; Space
CLR:    MOV  M,A
        INX  H
        DCR  C          ; C starts at 0, wraps to FF, counts 256
        JNZ  CLR
        DCR  B
        JNZ  CLR
        
        ; Write "HELLO WORLD" at row 8, col 26 (roughly centered)
        ; Address = CC00 + 8*64 + 26 = CC00 + 200 + 1A = CE1Ah
        LXI  H,0CE1Ah
        LXI  D,MSG
PLOOP:  LDAX D
        ORA  A
        JZ   DONE
        MOV  M,A
        INX  H
        INX  D
        JMP  PLOOP

DONE:   HLT             ; Or loop forever

MSG:    DB   'HELLO WORLD',0
```

---

## References

- Processor Technology VDM-1 Assembly and Test Manual, Rev E (110 pages)
- SOLOS/CUTER User's Manual (Processor Technology)
- CONSOL source code (sol20.org/programs/consol.asm)
- VDM-2021 build documentation (physicsrob.github.io/vdm1/)
- David Hansel's VDM-1 Emulator (github.com/dhansel/VDM1)
- Altair 8800 Simulator Manual — VDM-1 section (retrocmp.de)
- BYTE Magazine, December 1976 — VDM-1 Product Review
- Wikipedia: VDM-1
- s100computers.com: Processor Technology VDM-1
