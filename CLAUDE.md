# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JX Monitor is a pure Intel 8080 assembly machine-language monitor for Altair 8800, IMSAI, and z80pack simulator. It produces a single flat binary (~3.5KB) with interactive memory inspection, I/O port access, RAM testing, and optional Altair BASIC integration.

## Build Commands

```bash
make                  # Build flat binary (default)
make hex              # Build Intel HEX for simulator
make run              # Build and run in cpmsim simulator
make basic            # Build standalone 4K BASIC
make basic8k          # Build standalone 8K BASIC
make disk             # Create boot disk image (requires Node.js)
make test             # Run full test suite (build matrix + functional)
make clean            # Remove build artifacts
make info             # Display current configuration
make CONFIG=config.mk.sim run   # Build with alternate hardware config
```

The assembler is z80asm from z80pack (expected at `../z80pack/z80asm/z80asm`). Simulator is cpmsim at `../z80pack/cpmsim/cpmsim`.

## Test Infrastructure

Tests use Expect/Tcl and run against cpmsim:
- `tests/run-tests.sh` — test runner entry point
- `tests/test-build-matrix.sh` — Phase 1: builds 3 configs × 3 targets
- `tests/harness.exp` — shared Expect framework
- `tests/test-*.exp` — individual functional tests (boot, dump, write, io, basic, etc.)

Run a single test: `expect -f tests/test-boot.exp` (after building with `make hex CONFIG=config.mk.sim`)

## Architecture

**Single-file assembly build**: `src/bios/bios.asm` is the entry point that INCLUDEs all modules:

```
src/bios/bios.asm        → Boot, PUTCHAR, GETCHAR, MEMPROBE
  ├── serial.asm          → Serial driver (8251/6850/cpmsim, configurable ports)
  ├── video.asm           → VDM-1 framebuffer driver (64x16, conditional on VIDEO_BASE)
  ├── ../lib/print.asm    → PRINTS, PRHEX8, PRHEX16, PRDEC16, PRCRLF
  ├── ../lib/string.asm   → STRLEN, STRCMP, STRCPY, STRTOUPPER
  ├── ../lib/banner.asm   → Boot messages
  ├── ../monitor.asm      → Command loop, dispatcher, all command handlers
  └── ../cmd/term.asm     → Terminal emulator (optional, ENABLE_TERM=1)
```

**BASIC** lives in `src/basic/` with separate standalone and loadable entry points for 4K and 8K variants.

**Dual output**: PUTCHAR sends to both serial (CONOUT) and video (V_PUTCH). All print routines go through PUTCHAR, so output appears on both displays automatically.

**Memory layout** (64KB, load-at-zero): Monitor at 0000H, free RAM above, VDM-1 framebuffer at CC00H, stack below framebuffer.

## Hardware Configuration

All hardware settings live in `config.mk` (active config) with presets in `config.mk.*` files:
- `config.mk` — primary (currently IMSAI SIO-2 with VDM-1)
- `config.mk.sim` — cpmsim simulator (serial-only, no video)
- `config.mk.sio` — Altair 88-2SIO

Key variables: `MEM_SIZE`, `BIOS_BASE`, `STACK_TOP`, `VIDEO_BASE`, `SIO_DATA/STATUS/RX_MASK/TX_MASK`, `ENABLE_BASIC` (0/1/2), `ENABLE_TERM` (0/1). These are passed to the assembler as `-d` defines.

## Assembly Conventions

- **8080-only instructions** — no Z80 extensions (assembler flag `-8`)
- Labels at column 1 with colon; instructions indented
- Null-terminated strings: `DB 'text',0`
- Document input/output registers and destroyed registers for each routine

### z80asm Quirks

- `INCLUDE` filenames must NOT be quoted
- `INCLUDE` paths resolve relative to CWD (the Makefile `cd`s into `src/bios/` before assembly)
- `IF`/`ENDIF` directives must not start in column 1
- Symbol names limited to 8 chars by default; project uses `-e32` for 32-char symbols
- See `docs/Z80ASM_BUGS.md` for additional known issues

## Optional Module Pattern

To add a new optional command module:
1. Source file in `src/cmd/` wrapped in `IF ENABLE_<NAME>` / `ENDIF`
2. Config flag in `config.mk` and presets
3. Makefile adds `-dENABLE_<NAME>` to `MOD_DEFINES`
4. `bios.asm` adds `IFNDEF` default (EQU 0) + unconditional `INCLUDE`
5. `monitor.asm` gets IF-gated dispatch entries, command strings, and help text

## Hardware Reference Skills

Detailed hardware programming references live in `.claude/skills/`. Consult the relevant file when working on drivers, I/O routines, or hardware-specific code:

- `IMSAI-SIO2.skill.md` — Intel 8251 USART (IMSAI SIO-2 board): initialization, status bits, TX/RX polling
- `MITS-88-2SIO.skill.md` — Motorola MC6850 ACIA (Altair 88-2SIO board): control register, status register, bootstrap loaders
- `IMSAI-MIO.skill.md` — TR1602 UART (IMSAI MIO board): no-init serial, parallel ports, cassette interface
- `VDM-1.skill.md` — Processor Technology VDM-1: memory-mapped video at CC00H, hardware scroll, cursor, escape sequences
- `88-DCDD.skill.md` — MITS 88-DCDD floppy controller: disk I/O ports 08-0Ah, sector format, timing-critical read loops
- `MITS.Bootloader.skill.md` — Altair disk boot loader: Intel HEX format, 8080 instruction set, relocation, boot sequence

**When to consult**: Modifying `serial.asm`, `video.asm`, adding disk support, writing bootstrap code, or porting between hardware configurations. The status bit layouts and initialization sequences differ significantly between the IMSAI 8251, Altair MC6850, and IMSAI MIO TR1602 UARTs.

## Key Documentation

- `DESIGN.md` — architecture spec, memory layout, command reference
- `TOOLCHAIN.md` — z80asm syntax reference, cpmsim usage
- `docs/BUILD_SYSTEM.md` — build configuration details
- `docs/Z80ASM_BUGS.md` — assembler quirks and workarounds
