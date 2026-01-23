# JX Development Toolchain

This document describes the development toolchain for building and testing the JX Operating System for Intel 8080 computers.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Project Structure](#3-project-structure)
4. [Configuration](#4-configuration)
5. [Build System](#5-build-system)
6. [Assembly Language](#6-assembly-language)
7. [Testing and Simulation](#7-testing-and-simulation)
8. [Memory Configurations](#8-memory-configurations)
9. [Workflow Examples](#9-workflow-examples)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Overview

The JX toolchain provides everything needed to develop, assemble, and test 8080 assembly code for the JX operating system. It is built around:

- **z80asm** - A cross-assembler that supports Intel 8080 mode
- **cpmsim** - A CP/M simulator from z80pack for testing
- **GNU Make** - Build automation

The toolchain supports multiple memory configurations (32KB, 48KB, 64KB) and produces both Intel HEX and raw binary output formats.

---

## 2. Prerequisites

### 2.1 Required Software

| Software | Purpose | Notes |
|----------|---------|-------|
| z80pack | Assembler and simulator | Must be compiled |
| GNU Make | Build automation | Usually pre-installed on Unix systems |
| Bash | Shell scripts | Required for helper scripts |

### 2.2 Installing z80pack

If z80pack is not already compiled:

```bash
cd /path/to/z80pack

# Build the assembler
cd z80asm
make
cd ..

# Build the simulator
cd cpmsim/srcsim
make
cd ../..
```

### 2.3 Verifying Installation

```bash
# Check assembler
/path/to/z80pack/z80asm/z80asm
# Should display usage information

# Check simulator
/path/to/z80pack/cpmsim/cpmsim -h
# Should display help message
```

---

## 3. Project Structure

```
jx/
├── config.mk                    # Toolchain configuration
├── Makefile                     # Main build system
├── DESIGN.md                    # System architecture specification
├── TOOLCHAIN.md                 # This document
│
├── scripts/
│   ├── run-test.sh             # Run a test in the simulator
│   └── build-all-configs.sh    # Build for all memory sizes
│
├── src/
│   ├── include/
│   │   └── system.inc          # Common definitions and macros
│   │
│   ├── bios/
│   │   └── bios.asm            # BIOS implementation
│   │
│   ├── bdos/
│   │   └── bdos.asm            # BDOS implementation
│   │
│   ├── ccp/
│   │   └── (future)            # Console Command Processor
│   │
│   └── test/
│       ├── hello.asm           # Hello world test program
│       └── minimal.asm         # Minimal I/O test
│
└── build/                       # Output directory (created by make)
    ├── bios.hex                # Assembled BIOS
    ├── bdos.hex                # Assembled BDOS
    ├── jx.bin                  # Combined system image
    └── test/
        ├── hello.hex           # Test program (Intel HEX)
        ├── hello.bin           # Test program (raw binary)
        └── ...
```

### 3.1 Key Files

| File | Purpose |
|------|---------|
| `config.mk` | All configurable paths and options |
| `Makefile` | Build rules and targets |
| `src/include/system.inc` | Shared constants, addresses, and macros |

---

## 4. Configuration

### 4.1 Configuration File (config.mk)

All toolchain settings are in `config.mk`. Edit this file to customize your environment.

```makefile
# Path to z80pack installation
Z80PACK_DIR = /Users/mreppot/src/z80pack

# Assembler location (derived from Z80PACK_DIR)
Z80ASM = $(Z80PACK_DIR)/z80asm/z80asm

# Simulator location (derived from Z80PACK_DIR)
SIMULATOR = $(Z80PACK_DIR)/cpmsim/cpmsim

# Default memory size (32, 48, or 64)
MEM_SIZE = 64
```

### 4.2 Assembler Flags

The assembler is invoked with these flags:

| Flag | Purpose |
|------|---------|
| `-8` | 8080 mode - reject Z80-only instructions |
| `-l` | Generate listing file (.lis) |
| `-T` | Omit symbol table from listing |
| `-sn` | Output symbol table sorted numerically |
| `-p0` | Fill unused memory with 0x00 |
| `-fb` | Output flat binary format |
| `-fh` | Output Intel HEX format |

### 4.3 Memory Configuration

Memory addresses are automatically calculated based on `MEM_SIZE`:

| MEM_SIZE | MEMTOP | BIOS_BASE | BDOS_BASE | TPA_TOP | TPA Size |
|----------|--------|-----------|-----------|---------|----------|
| 32 | 0x8000 | 0x7E00 | 0x7600 | 0x7500 | ~29KB |
| 48 | 0xC000 | 0xBE00 | 0xB600 | 0xB500 | ~45KB |
| 64 | 0x0000* | 0xFE00 | 0xF600 | 0xF500 | ~62KB |

*MEMTOP of 0x0000 represents 64KB (wraps in 16-bit arithmetic)

These values are passed to the assembler as defines:
- `-dMEMTOP=xxxxx`
- `-dBIOS_BASE=xxxxx`
- `-dBDOS_BASE=xxxxx`
- `-dTPA_TOP=xxxxx`
- `-dMEM_SIZE=xx`

---

## 5. Build System

### 5.1 Make Targets

| Target | Description |
|--------|-------------|
| `make` or `make all` | Build complete system |
| `make test` | Build all test programs |
| `make test-<name>` | Build specific test (e.g., `make test-hello`) |
| `make bios` | Build BIOS only |
| `make bdos` | Build BDOS only |
| `make run` | Run system in simulator |
| `make run-test TEST=<name>` | Run specific test |
| `make clean` | Remove build artifacts |
| `make distclean` | Remove entire build directory |
| `make check-tools` | Verify toolchain availability |
| `make info` | Display current configuration |
| `make help` | Show available targets |

### 5.2 Build Options

Override defaults on the command line:

```bash
# Build for 32KB system
make MEM_SIZE=32

# Build to alternate directory
make BUILD_DIR=build-debug

# Combine options
make MEM_SIZE=32 BUILD_DIR=build-32k
```

### 5.3 Output Formats

The build system produces two output formats:

#### Intel HEX (.hex)
- Contains load address information
- Human-readable ASCII format
- Use with simulator's `-x` flag
- Suitable for EPROM programmers

Example:
```
:20010000310303212301CD160121AD01...
:00000001FF
```

#### Raw Binary (.bin)
- No address information
- Direct memory image
- Use for ROM burning
- Use for embedding in other tools

### 5.4 Build Process

```
┌─────────────────┐
│  Source Files   │
│   (.asm)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌──────────────┐
│    z80asm       │────▶│ Listing File │
│   Assembler     │     │   (.lis)     │
└────────┬────────┘     └──────────────┘
         │
         ├─────────────────┐
         ▼                 ▼
┌─────────────────┐ ┌─────────────────┐
│   Intel HEX     │ │   Raw Binary    │
│    (.hex)       │ │    (.bin)       │
└─────────────────┘ └─────────────────┘
```

---

## 6. Assembly Language

### 6.1 Assembler Syntax

The z80asm assembler uses Zilog/Intel syntax. When in 8080 mode (`-8`), only 8080 instructions are accepted.

#### Basic Syntax

```asm
; Comments start with semicolon
LABEL:                      ; Labels end with colon
        MVI     A,42H       ; Instruction with operand
        OUT     01H         ; I/O instruction

CONSTANT EQU    1234H       ; Constant definition
VARIABLE DB     0           ; Define byte
STRING   DB     'Hello',0   ; String with null terminator
BUFFER   DS     128         ; Reserve 128 bytes
```

#### Numeric Formats

| Format | Example | Value |
|--------|---------|-------|
| Decimal | `123` | 123 |
| Hexadecimal | `0ABH` or `0xAB` | 171 |
| Binary | `10101010B` | 170 |
| Octal | `177O` or `177Q` | 127 |
| Character | `'A'` | 65 |

**Important**: Hex numbers starting with A-F must be prefixed with `0` (e.g., `0FE00H` not `FE00H`).

#### Directives

| Directive | Purpose | Example |
|-----------|---------|---------|
| `ORG` | Set origin address | `ORG 0100H` |
| `EQU` | Define constant | `BDOS EQU 0005H` |
| `DB` | Define byte(s) | `DB 'Hello',0` |
| `DW` | Define word(s) | `DW 1234H` |
| `DS` | Define space | `DS 256` |
| `END` | End of source | `END START` |
| `INCLUDE` | Include file | `INCLUDE "system.inc"` |

#### Conditional Assembly

```asm
IFDEF SYMBOL
    ; Assembled if SYMBOL is defined
ENDIF

IFNDEF SYMBOL
    ; Assembled if SYMBOL is not defined
ENDIF

IF EXPRESSION
    ; Assembled if EXPRESSION is non-zero
ENDIF
```

### 6.2 8080 Instruction Set

The assembler in 8080 mode accepts only valid 8080 instructions:

#### Data Transfer
```asm
MOV     r,r'        ; Move register to register
MVI     r,data      ; Move immediate to register
LXI     rp,data16   ; Load register pair immediate
LDA     addr        ; Load A from memory
STA     addr        ; Store A to memory
LHLD    addr        ; Load HL from memory
SHLD    addr        ; Store HL to memory
LDAX    rp          ; Load A indirect
STAX    rp          ; Store A indirect
XCHG                ; Exchange DE and HL
```

#### Arithmetic/Logic
```asm
ADD     r           ; Add register to A
ADI     data        ; Add immediate to A
ADC     r           ; Add with carry
ACI     data        ; Add immediate with carry
SUB     r           ; Subtract register from A
SUI     data        ; Subtract immediate
SBB     r           ; Subtract with borrow
SBI     data        ; Subtract immediate with borrow
INR     r           ; Increment register
DCR     r           ; Decrement register
INX     rp          ; Increment register pair
DCX     rp          ; Decrement register pair
DAD     rp          ; Add register pair to HL
ANA     r           ; AND register with A
ANI     data        ; AND immediate with A
ORA     r           ; OR register with A
ORI     data        ; OR immediate with A
XRA     r           ; XOR register with A
XRI     data        ; XOR immediate with A
CMP     r           ; Compare register with A
CPI     data        ; Compare immediate with A
RLC                 ; Rotate A left
RRC                 ; Rotate A right
RAL                 ; Rotate A left through carry
RAR                 ; Rotate A right through carry
CMA                 ; Complement A
CMC                 ; Complement carry
STC                 ; Set carry
DAA                 ; Decimal adjust A
```

#### Branch
```asm
JMP     addr        ; Jump unconditional
JZ/JNZ  addr        ; Jump if zero/not zero
JC/JNC  addr        ; Jump if carry/no carry
JP/JM   addr        ; Jump if plus/minus
JPE/JPO addr        ; Jump if parity even/odd
CALL    addr        ; Call subroutine
CZ/CNZ  addr        ; Call if zero/not zero
CC/CNC  addr        ; Call if carry/no carry
RET                 ; Return from subroutine
RZ/RNZ              ; Return if zero/not zero
RC/RNC              ; Return if carry/no carry
PCHL                ; Jump to address in HL
RST     n           ; Restart (n = 0-7)
```

#### Stack/I/O/Control
```asm
PUSH    rp          ; Push register pair
POP     rp          ; Pop register pair
XTHL                ; Exchange top of stack with HL
SPHL                ; Move HL to SP
IN      port        ; Input from port
OUT     port        ; Output to port
EI                  ; Enable interrupts
DI                  ; Disable interrupts
HLT                 ; Halt CPU
NOP                 ; No operation
```

### 6.3 Common Include File

The file `src/include/system.inc` provides standard definitions:

```asm
; Include at the top of your source files
INCLUDE "src/include/system.inc"

; Provides:
; - Page Zero addresses (BOOT_ENTRY, BDOS_ENTRY, etc.)
; - BDOS function numbers (C_READ, C_WRITE, F_OPEN, etc.)
; - FCB structure offsets
; - BIOS jump table offsets
; - ASCII character codes
; - I/O port definitions
```

### 6.4 Programming Conventions

#### Register Usage
| Register | Convention |
|----------|------------|
| A | Accumulator, return values |
| BC | Parameter passing, counter |
| DE | Parameter passing, addresses |
| HL | Addresses, 16-bit return values |
| SP | Stack pointer (don't modify carelessly) |

#### Calling BDOS
```asm
; Print a character
        MVI     C,C_WRITE       ; Function number in C
        MVI     E,'A'           ; Parameter in E
        CALL    BDOS_ENTRY      ; Call BDOS at 0x0005

; Print a string
        MVI     C,C_WRITESTR    ; Function 9
        LXI     D,MESSAGE       ; Address in DE
        CALL    BDOS_ENTRY

MESSAGE:
        DB      'Hello, World!$' ; '$' terminates string
```

#### Program Structure
```asm
;========================================
; Program: example.asm
; Description: Example program structure
;========================================

        INCLUDE "src/include/system.inc"

        ORG     TPA_BASE        ; 0x0100

;----------------------------------------
; Entry Point
;----------------------------------------
START:
        LXI     SP,STACK        ; Initialize stack

        ; ... program code ...

        JMP     BOOT_ENTRY      ; Exit via warm boot

;----------------------------------------
; Subroutines
;----------------------------------------
SUBROUTINE:
        ; ...
        RET

;----------------------------------------
; Data Section
;----------------------------------------
DATA:   DB      0
BUFFER: DS      128

;----------------------------------------
; Stack
;----------------------------------------
        DS      256             ; 256 bytes for stack
STACK   EQU     $

;----------------------------------------
        END     START
```

---

## 7. Testing and Simulation

### 7.1 The cpmsim Simulator

cpmsim is an 8080/Z80 simulator that emulates:
- Intel 8080 CPU (with `-8` flag)
- Console I/O via ports 0 (status) and 1 (data)
- Disk I/O via ports 10-16
- 64KB of RAM

### 7.2 I/O Port Map

| Port | Read | Write |
|------|------|-------|
| 0 | Console status (0=no char, FF=ready) | Console status |
| 1 | Console data | Console data |
| 10 | - | Drive select |
| 11 | - | Track number |
| 12 | - | Sector number |
| 13 | - | FDC command (0=read, 1=write) |
| 14 | FDC status | - |
| 15 | - | DMA address low |
| 16 | - | DMA address high |

### 7.3 Running Tests

#### Using the Helper Script

```bash
# Run a specific test
./scripts/run-test.sh hello

# The script will:
# 1. Build the test if needed
# 2. Launch cpmsim with the test program
# 3. The simulator runs interactively
```

#### Using Make

```bash
# Build and run
make test-hello
make run-test TEST=hello
```

#### Direct Invocation

```bash
# Run with Intel HEX file (recommended)
/path/to/cpmsim -8 -m 00 -x build/test/hello.hex

# Flags:
#   -8     : 8080 mode
#   -m 00  : Initialize memory to 0x00
#   -x     : Load and execute file
```

### 7.4 Writing Test Programs

Test programs should:
1. Start at `ORG 0100H` (TPA base)
2. Initialize their own stack
3. Use direct I/O or BDOS calls for console output
4. End with `HLT` or jump to `0000H`

Example test program:

```asm
;========================================
; Test: mytest.asm
;========================================
        ORG     0100H

CONDATA EQU     1               ; Console data port

START:
        LXI     SP,STACK

        ; Print message
        LXI     H,MESSAGE
LOOP:   MOV     A,M
        ORA     A
        JZ      DONE
        OUT     CONDATA
        INX     H
        JMP     LOOP

DONE:   HLT

MESSAGE:
        DB      'Test passed!',0DH,0AH,0

        DS      64
STACK   EQU     $

        END     START
```

### 7.5 Debugging Tips

1. **Check the listing file** (.lis) for assembly errors and addresses
2. **Verify load address** - simulator shows "START: 0100H" for correct loading
3. **Use minimal tests** to isolate issues
4. **Check I/O ports** - ensure you're using the correct port numbers

---

## 8. Memory Configurations

### 8.1 Building for Different Memory Sizes

```bash
# Build for 32KB
make clean
make MEM_SIZE=32

# Build for 48KB
make clean
make MEM_SIZE=48

# Build for 64KB (default)
make clean
make MEM_SIZE=64

# Build all configurations
./scripts/build-all-configs.sh
```

### 8.2 Memory Map Comparison

```
        32KB                    48KB                    64KB
    ┌──────────┐ 7FFF      ┌──────────┐ BFFF      ┌──────────┐ FFFF
    │   BIOS   │           │   BIOS   │           │   BIOS   │
    ├──────────┤ 7E00      ├──────────┤ BE00      ├──────────┤ FE00
    │   BDOS   │           │   BDOS   │           │   BDOS   │
    ├──────────┤ 7600      ├──────────┤ B600      ├──────────┤ F600
    │  Stack   │           │  Stack   │           │  Stack   │
    ├──────────┤ 7500      ├──────────┤ B500      ├──────────┤ F500
    │          │           │          │           │          │
    │   TPA    │           │   TPA    │           │   TPA    │
    │ (~29KB)  │           │ (~45KB)  │           │ (~62KB)  │
    │          │           │          │           │          │
    ├──────────┤ 0100      ├──────────┤ 0100      ├──────────┤ 0100
    │ Page 0   │           │ Page 0   │           │ Page 0   │
    └──────────┘ 0000      └──────────┘ 0000      └──────────┘ 0000
```

### 8.3 Conditional Assembly for Memory Size

```asm
; In your source code, check MEM_SIZE if needed
IFDEF MEM_SIZE
  IF MEM_SIZE EQ 32
        ; 32KB-specific code
  ENDIF
  IF MEM_SIZE EQ 64
        ; 64KB-specific code
  ENDIF
ENDIF
```

---

## 9. Workflow Examples

### 9.1 Adding a New System Component

1. Create source file in appropriate directory:
   ```bash
   touch src/ccp/ccp.asm
   ```

2. Add standard header:
   ```asm
   ;========================================
   ; JX Console Command Processor
   ;========================================
   INCLUDE "src/include/system.inc"

   IFNDEF CCP_BASE
   CCP_BASE EQU BDOS_BASE - 0800H
   ENDIF

           ORG     CCP_BASE
   ; ...
   ```

3. Build:
   ```bash
   make
   ```

### 9.2 Adding a New Test Program

1. Create test file:
   ```bash
   touch src/test/mytest.asm
   ```

2. Write test code (see Section 7.4)

3. Build and run:
   ```bash
   make test-mytest
   ./scripts/run-test.sh mytest
   ```

### 9.3 Full Development Cycle

```bash
# 1. Edit source code
vim src/bios/bios.asm

# 2. Build
make

# 3. Check for errors in listing
less build/bios.lis

# 4. Test
./scripts/run-test.sh hello

# 5. Build for all memory configurations
./scripts/build-all-configs.sh

# 6. Clean up
make clean
```

---

## 10. Troubleshooting

### 10.1 Common Assembler Errors

#### "invalid opcode"
- Z80-only instruction used in 8080 mode
- Check that you're using 8080 mnemonics

#### "undefined symbol"
- Symbol not defined before use
- Check spelling and case
- Ensure include files are included

#### "error in option -d: undefined symbol"
- Hex number starts with A-F without leading 0
- Use `0FE00H` not `FE00H`

#### "phase error"
- Label address changed between passes
- Usually caused by forward references in `EQU`

### 10.2 Common Build Errors

#### "Assembler not found"
```bash
# Check config.mk Z80PACK_DIR setting
make check-tools

# Verify assembler exists and is executable
ls -la /path/to/z80pack/z80asm/z80asm
```

#### "No rule to make target"
- Source file doesn't exist
- Check filename spelling
- Ensure file is in correct directory

### 10.3 Simulator Issues

#### Program doesn't produce output
- Verify correct I/O ports (0 for status, 1 for data)
- Check that program was loaded at correct address
- Look for "LOADED: xxxx" in simulator output

#### Simulator hangs
- Program may be in infinite loop
- Press Ctrl-C to stop
- Check program logic

#### "can't exec cpmrecv process"
- This is a warning, not an error
- Auxiliary tools not installed
- Does not affect basic operation

### 10.4 Getting Help

1. Check the listing file for detailed assembly information
2. Use `make info` to verify configuration
3. Create minimal test cases to isolate problems
4. Review DESIGN.md for system architecture details

---

## Appendix A: Quick Reference Card

### Make Commands
```
make                Build all (64KB)
make MEM_SIZE=32    Build for 32KB
make test           Build tests
make test-NAME      Build specific test
make run-test TEST=NAME  Run test
make clean          Clean build
make info           Show config
make help           Show help
```

### Assembler Invocation
```
z80asm -8 -l -fh -o output.hex source.asm
       │  │  │
       │  │  └── Output format (fh=hex, fb=bin)
       │  └───── Generate listing
       └──────── 8080 mode
```

### Key Addresses
```
0000H  Warm boot entry, Page Zero start
0005H  BDOS entry point
005CH  Default FCB
0080H  Default DMA buffer
0100H  TPA start (program load address)
```

### I/O Ports
```
Port 0  Console status
Port 1  Console data
Port 10 Drive select
Port 11 Track
Port 12 Sector
Port 13 FDC command
Port 14 FDC status
Port 15 DMA low
Port 16 DMA high
```

---

*Document Version: 1.0*
*Last Updated: 2026-01-22*
