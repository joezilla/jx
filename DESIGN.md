# JX Monitor -- Design Specification

## Version 0.4

This document defines the architecture of JX, an interactive machine-language monitor for Intel 8080 computers.

---

## 1. Design Goals

### 1.1 Primary Objectives

- **Simplicity**: Single flat binary, no layers or abstraction beyond hardware drivers
- **Utility**: Practical tool for inspecting and manipulating memory on an 8080 system
- **Dual output**: All display output to both serial console and VDM-1 video
- **Small footprint**: Fits in ~3.5KB at the top of RAM

### 1.2 Non-Goals

- Operating system services (no BDOS, no system calls, no file I/O)
- Binary compatibility with CP/M
- Support for systems with less than 32KB RAM

---

## 2. Hardware Requirements

### 2.1 Minimum Configuration

| Component | Requirement |
|-----------|-------------|
| CPU | Intel 8080A or compatible (8085, Z80 in 8080 mode) |
| RAM | 32KB minimum, contiguous from 0x0000 |
| Console | Serial terminal (keyboard input, text output) |

### 2.2 Optional Hardware

| Component | Details |
|-----------|---------|
| VDM-1 video | Processor Technology VDM-1, 64x16 at C000H |

### 2.3 I/O Ports (cpmsim)

| Port | Function |
|------|----------|
| 0 | Console status (FFH = char ready, 00H = not ready) |
| 1 | Console data (read = receive, write = transmit) |

### 2.4 Interrupt Model

JX uses polled I/O. Interrupts are disabled at boot (`DI`).

---

## 3. Memory Layout

The monitor's placement is controlled by `BIOS_BASE`, and comes in two
shapes: **load-at-zero** (`BIOS_BASE=0`, the current default in
`config.mk`) and **ROM-capable** (`BIOS_BASE` > 0), which relocates the
monitor so it can be burned into a real EPROM.

### 3.1 Load-at-zero (BIOS_BASE=0)

```
0000-xxxx  Monitor code + data (~3.5KB)
xxxx-FFFF  Free RAM
             Available for user programs via 'go' command
[C000-C3FF VDM-1 video framebuffer, if enabled]
```

This is the simplest layout: the whole image, including mutable
variables, is one RAM-resident blob starting at address 0. There is no
ROM/RAM split.

### 3.2 ROM-capable (BIOS_BASE > 0)

```
0000-00FF        Page Zero
                   0000: JMP WBOOT (return to monitor - written at boot)
0100-DATA_END-1  Mutable data segment (RAM: cursor position, command
                   buffer, detected memory size, etc.)
DATA_END-xxxx    Free RAM (below the monitor)
BIOS_BASE-       Monitor code (~3.5KB) - may be ROM-resident
  CODE_END-1
CODE_END-xxxx    Free RAM (above the monitor, if any)
[VIDEO_BASE-     VDM-1 video framebuffer, if enabled
  +VIDEO_SIZE-1]
```

Because the code above `BIOS_BASE` may live in read-only memory, all
mutable state is kept out of it and placed in a separate RAM segment
at `DATA_BASE` (default `0100H`) instead. `BIOS_BASE` can sit anywhere
in the address space that the target hardware allows - not only at
the top of RAM - so free RAM can exist both below and above the
monitor's code window. `MEMPROBE`/`PRMMAP` (in `bios.asm`) and the `m`
command (in `monitor.asm`) account for both windows.

To actually run this layout on hardware, something must redirect
execution to `BIOS_BASE` on reset without relying on code at 0000H -
either a board feature like the 88-2SIOJP's "Jump-Start" (see
`.claude/skills/88-2SIOJP.skill.md`), which forces a `JMP BIOS_BASE`
onto the bus after reset, or (for testing under `cpmsim`, which always
starts at `PC=0000H`) the `SIM_STUB` build option, which assembles a
`JMP BOOT` at address 0000H. `SIM_STUB` is simulator-only and is not
part of a real ROM image.

### 3.3 Page Zero (0000-00FF)

When `BIOS_BASE > 0`, page zero holds one entry point, written by
`INIT_PAGE0` at boot (not present in the ROM image itself):

| Address | Contents | Purpose |
|---------|----------|---------|
| 0000H | JMP WBOOT | Warm boot -- returns to monitor prompt |

Programs executed via the `go` command can return to the monitor with `JMP 0000H`.

### 3.4 BIOS Jump Table (BIOS_BASE > 0 only)

External programs and hardware reset-vector redirects use a fixed
jump table at the start of the monitor's code:

| Offset | Target | Purpose |
|--------|--------|---------|
| BIOS_BASE+0  | BOOT    | Cold-boot / hardware reset entry |
| BIOS_BASE+3  | WBOOT   | Warm boot |
| BIOS_BASE+6  | CONST   | Console status |
| BIOS_BASE+9  | GETCHAR | Blocking read |
| BIOS_BASE+12 | PUTCHAR | Dual (serial+video) output |

`BIOS_BASE+0` must always be a full cold-boot entry point, since a
hardware reset-vector redirect (like Jump-Start) lands there directly
and expects serial/video hardware to be initialized.

---

## 4. System Architecture

### 4.1 Single Binary

The entire system is a single assembly file (`bios.asm`) that INCLUDEs all components:

```
bios.asm          Boot, PUTCHAR, GETCHAR, MEMPROBE
  INCLUDE serial.asm    CONST, CONIN, CONOUT
  INCLUDE video.asm     V_INIT, V_PUTCH, V_SCROLL, V_CLEAR
  INCLUDE print.asm     PRINTS, PRCRLF, PRHEX8, PRHEX16, PRDEC16
  INCLUDE string.asm    STRLEN, STRCMP, STRCPY, STRTOUPPER
  INCLUDE monitor.asm   MONITOR, CMD_DUMP, CMD_TEST, CMD_WRITE, etc.
  INCLUDE cmd/term.asm  DO_TERM (optional, ENABLE_TERM=1)
```

### 4.2 Boot Sequence

1. `DI` -- disable interrupts
2. Set stack pointer to STACK_TOP (grows downward into free RAM)
3. Print banner via serial only (video not yet initialized)
4. Detect memory -- probe free RAM in 256-byte pages, skipping the
   monitor's own ROM/code window when BIOS_BASE > 0
5. Initialize VDM-1 video (clear framebuffer, reset cursor)
6. Set up Page Zero: `JMP WBOOT` at 0000H (BIOS_BASE > 0 only)
7. Print memory map
8. Enter monitor command loop

When `BIOS_BASE > 0`, this sequence is entered via `BOOT`, which is
reachable both from `JMP BOOT` at `BIOS_BASE+0` (the entry a hardware
reset-vector redirect lands on) and, for simulator testing only, from
the `SIM_STUB`-gated `JMP BOOT` at address 0000H.

### 4.3 Dual Output

`PUTCHAR` sends every character to both serial (CONOUT) and video (V_PUTCH). `GETCHAR` reads from serial only (the keyboard).

```
PUTCHAR:  A -> CONOUT (serial port 1)
              -> V_PUTCH (write to C000H framebuffer)

GETCHAR:  CONIN (serial port 0/1) -> A
```

All print routines (PRINTS, PRHEX16, PRCRLF, etc.) call PUTCHAR, so all output automatically appears on both displays.

---

## 5. Monitor Commands

| Command | Syntax | Description |
|---------|--------|-------------|
| `d` / `dump` | `d <addr> [<end>]` | Hex dump with ASCII sidebar |
| `t` / `test` | `t [<start> <end>]` | Destructive RAM test (complement pattern) |
| `w` / `write` | `w <addr> <bb> ...` | Write hex bytes to memory |
| `g` / `go` | `g <addr>` | Execute code at address |
| `l` / `load` | `l <port>` | Load Intel HEX via serial (1=con, 2=aux) |
| `m` / `mem` | `m` | Show memory layout and detected RAM |
| `in` / `i` | `in <port>` | Read I/O port and display value |
| `out` / `o` | `out <port> <byte>` | Write byte to I/O port |
| `cls` | `cls` | Clear screen (ANSI escape + video clear) |
| `term` / `e` | `term` | Terminal emulator (SIO2 pass-through) [optional] |
| `b` / `boot` | `b` | Boot drive 0 of an 88-DCDD / 88-MDS floppy [optional] |
| `?` / `help` | `?` | Show command list |

### 5.1 Hex Dump Format

```
F400: F3 31 00 F4 21 D1 FD CD  D1 F4 21 F8 FD CD D1 F4  .1..!.....!.....
```

16 bytes per line: address, hex bytes (split 8+8), ASCII printable chars (20H-7EH shown, others as `.`).

### 5.2 Hex Parsing

All addresses and byte values are entered in hexadecimal. The parser accepts 1-4 hex digits (0-9, A-F, a-f). No `0x` prefix or `H` suffix needed.

---

## 6. Video Subsystem

### 6.1 VDM-1 Specifications

- 64 columns x 16 rows = 1024 bytes at C000H-C3FFH
- Pure memory-mapped framebuffer (write ASCII bytes directly)
- No hardware scrolling -- software copies rows up and clears the last row

### 6.2 Video Driver

| Routine | Function |
|---------|----------|
| V_INIT | Clear screen, reset cursor to (0,0) |
| V_PUTCH | Write character at cursor, advance cursor, handle CR/LF/BS/TAB |
| V_SCROLL | Copy 15 rows up (960 bytes), clear row 16 |
| V_CLEAR | Fill framebuffer with spaces |

### 6.3 Conditional Compilation

Video support is conditional on `VIDEO_BASE` being nonzero. Building with `VIDEO_BASE=0` produces a serial-only monitor.

---

## 6a. Optional Command Modules

### 6a.1 Module Pattern

Optional commands live in `src/cmd/<name>.asm`. Each module follows this recipe:

1. **Source file** wrapped in `IF ENABLE_<NAME>` / `ENDIF` (self-gating)
2. **Flag** in `config.mk` (`ENABLE_<NAME> = 1`) and `config.mk.sim` (`= 0`)
3. **Makefile** conditional `-dENABLE_<NAME>` in `MOD_DEFINES`
4. **bios.asm** `IFNDEF` default (EQU 0) + unconditional `INCLUDE`
5. **monitor.asm** IF-gated dispatch entries, command strings, and help text

### 6a.2 Terminal Emulator (`term` / `e`)

Transparent serial pass-through to SIO Channel B. Enabled with `ENABLE_TERM=1` in `config.mk`.

- Initializes SIO2 (8251 USART) on entry
- Console keystrokes are sent to SIO2 TX
- SIO2 RX data is displayed on the console via PUTCHAR
- ESC (1BH) exits back to monitor
- ~200 bytes (code + dispatch + strings)

### 6a.3 Floppy Disk Boot (`b` / `boot`)

Boots drive 0 of a MITS 88-DCDD (8") or 88-MDS (minidisk)
controller: loads the disk's boot file to 0000H and jumps to it.
Enabled with `ENABLE_DISKBOOT=1`; takes `DISK_BASE` (controller's
first port, default 08H) and `BOOT_RAM_BASE` (512-byte scratch
region, default 04C00H).

Derived from CDBL 3.00 (Eberhard / Douglas), transcribed from the
published listing and verified byte-for-byte against its reference
image before adaptation. Auto-detects 8" vs. minidisk geometry,
walks the 2:1 sector interleave, retries a bad sector 16 times, and
write-verifies every byte it stores.

The command runs in two phases:

- **ROM phase** — drive select, wait for ready, seek track 0,
  detect the disk type. Nothing has been written to memory yet, so
  this phase uses the monitor's normal `PRINTS`/`CONST` routines and
  can return to the prompt. Unlike stock CDBL, each wait is bounded
  by a retry count and abortable with ESC; the sector-pulse polls
  keep their inner loops under the 30 µs `-SVALID` window by pushing
  the bound out to an outer loop (see the timing note in
  `diskboot.asm`).
- **RAM phase** — the sector read engine, relocated to
  `BOOT_RAM_BASE` and run there, because sector data landing at
  0000H would otherwise overwrite the running code. Uses the same
  `label+RELOC` template mechanism as `fwupdate.asm`.

`BOOT_RAM_BASE` must be page aligned, must have an even high byte,
and its 512-byte region must end at `xxFF` — the read loop's
terminator is `INR E` wrapping, and the overlay check tests both
pages with one compare.

On error (`C` checksum, `M` write-verify, `O` overlay) the engine
prints one line through an inlined `CONOUT` — the monitor's cursor
variables may be gone by then — and cold-starts the monitor
(`BIOS_BASE > 0`) or halts (load-at-zero, where the monitor itself
has been overwritten).

- ~340 bytes (code + dispatch + strings)

---

## 7. Serial Subsystem

### 7.1 cpmsim Console

| Routine | Function |
|---------|----------|
| CONST | Check if character available (non-blocking) |
| CONIN | Read character (blocking, strips parity) |
| CONOUT | Write character (immediate, no TX wait needed) |

cpmsim's console always accepts output immediately, so CONOUT does not need to poll TX status.

---

## 8. Source Code Organization

```
src/
├── bios/
│   ├── bios.asm        System entry, boot, PUTCHAR, GETCHAR, MEMPROBE
│   ├── serial.asm      Serial console driver (ports 0/1)
│   └── video.asm       VDM-1 video driver (C000H)
├── cmd/
│   ├── term.asm        Terminal emulator (optional, ENABLE_TERM)
│   ├── fwupdate.asm    EEPROM firmware update (optional, ENABLE_FWUPDATE)
│   └── diskboot.asm    88-DCDD floppy boot (optional, ENABLE_DISKBOOT)
├── lib/
│   ├── print.asm       PRINTS, PRCRLF, PRHEX8, PRHEX16, PRDEC8, PRDEC16
│   └── string.asm      STRLEN, STRCMP, STRCPY, STRTOUPPER
└── monitor.asm         Monitor command loop and all commands
```

---

## 9. Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-01-22 | Initial CP/M-style architecture |
| 0.2 | 2026-01-31 | Added CCP, BDOS, assembly library |
| 0.3 | 2026-02-13 | Rewrite as flat monitor OS; removed CP/M layers |
| 0.4 | 2026-02-19 | Added I/O port commands (in/out), Intel HEX loader, VDM-1 video |

---

## 10. References

- Intel 8080 Microcomputer Systems User's Manual
- Processor Technology VDM-1 documentation
- z80pack: https://github.com/udo-munk/z80pack
