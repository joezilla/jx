# JX Monitor -- Design Specification

## Version 0.3

This document defines the architecture of JX, an interactive machine-language monitor for Intel 8080 computers.

---

## 1. Design Goals

### 1.1 Primary Objectives

- **Simplicity**: Single flat binary, no layers or abstraction beyond hardware drivers
- **Utility**: Practical tool for inspecting and manipulating memory on an 8080 system
- **Dual output**: All display output to both serial console and VDM-1 video
- **Small footprint**: Fits in ~3KB at the top of RAM

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

### 3.1 Overview (64KB)

```
0000-00FF  Page Zero
             0000: JMP WBOOT (return to monitor)
0100-BFFF  Free RAM (~48KB)
             Available for user programs via 'go' command
C000-C3FF  VDM-1 video framebuffer (if enabled)
             64 columns x 16 rows = 1024 bytes
F400-FFFF  Monitor code + data (~3KB)
             Includes: boot, serial, video, print, string, monitor
```

### 3.2 Memory Configurations

| Total RAM | Monitor Base | Free RAM | Video |
|-----------|-------------|----------|-------|
| 32KB | 7400H | 0100-73FF | N/A |
| 48KB | B400H | 0100-B3FF | N/A |
| 64KB | F400H | 0100-BFFF | C000-C3FF |

### 3.3 Page Zero (0000-00FF)

Only one entry point is used:

| Address | Contents | Purpose |
|---------|----------|---------|
| 0000H | JMP WBOOT | Warm boot -- returns to monitor prompt |

Programs executed via the `go` command can return to the monitor with `JMP 0000H`.

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
```

### 4.2 Boot Sequence

1. `DI` -- disable interrupts
2. Set stack pointer to BIOS_BASE (grows downward into free RAM)
3. Print banner via serial only (video not yet initialized)
4. Detect memory -- probe from 32KB upward in 256-byte pages
5. Initialize VDM-1 video (clear framebuffer, reset cursor)
6. Set up Page Zero: `JMP WBOOT` at 0000H
7. Print memory map
8. Enter monitor command loop

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
| `m` / `mem` | `m` | Show memory layout and detected RAM |
| `cls` | `cls` | Clear screen (ANSI escape + video clear) |
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

---

## 10. References

- Intel 8080 Microcomputer Systems User's Manual
- Processor Technology VDM-1 documentation
- z80pack: https://github.com/udo-munk/z80pack
