# JX Operating System - Toolchain Guide

Complete reference for the JX development toolchain including assemblers, compilers, linkers, and simulators.

## Table of Contents

- [Overview](#overview)
- [Assembly Toolchain (z80pack)](#assembly-toolchain-z80pack)
- [C Toolchain (SDCC)](#c-toolchain-sdcc)
- [Installation](#installation)
- [Tool Reference](#tool-reference)
- [Build Workflow](#build-workflow)
- [Troubleshooting](#troubleshooting)

---

## Overview

The JX Operating System uses a dual-toolchain approach:

- **Assembly Toolchain**: z80pack (z80asm) for BIOS, BDOS, and system components
- **C Toolchain**: SDCC (Small Device C Compiler) for user applications and CCP

### Supported Targets

- **CPU**: Intel 8080 (8-bit microprocessor)
- **Architecture**: Von Neumann (unified code/data memory)
- **Memory**: 32KB, 48KB, or 64KB configurations
- **Simulator**: cpmsim from z80pack

---

## Assembly Toolchain (z80pack)

### z80asm - Assembler

**Purpose**: Assembles 8080/Z80 assembly language to machine code

**Version**: z80pack 1.36 or later

**Location**: `z80pack/z80asm/z80asm`

**Usage**:
```bash
z80asm [options] -o output.bin input.asm
```

**Supported Modes**:
- **8080 mode** (`-8`): Rejects Z80-only instructions
- **Z80 mode** (default): Accepts full Z80 instruction set

**JX Uses**: 8080 mode exclusively for compatibility

---

### z80asm Command-Line Options

**Output Format**:
- `-fb` - Flat binary (no load address, used for ROM images)
- `-fh` - Intel HEX format (includes load address, used for simulator)

**Listing Files**:
- `-l` - Generate listing file (.lis)
- `-T` - Omit symbol table from listing
- `-sn` - Sort symbol table numerically by address

**Memory Fill**:
- `-p0` - Fill unused memory with 0x00
- `-pFF` - Fill unused memory with 0xFF

**Defines**:
- `-dSYMBOL=VALUE` - Define assembler constant

**Example (JX BIOS build)**:
```bash
z80asm -8 -l -T -sn -p0 -fb \
       -dMEMTOP=0000H \
       -dBIOS_BASE=0FD00H \
       -dBDOS_BASE=0F500H \
       -dTPA_TOP=0F400H \
       -o build/bios.bin \
       src/bios/bios.asm
```

---

### z80asm Syntax

**Supported Directives**:
```asm
ORG     address         ; Set origin address
EQU     value           ; Define constant
DB      data            ; Define byte(s)
DW      data            ; Define word(s)
DS      count           ; Define space (reserve bytes)
INCLUDE "file"          ; Include another file
END                     ; End of assembly
```

**NOT Supported** (causes errors in z80pack 1.36):
- `IFNDEF`, `IFDEF`, `ENDIF` - Conditional assembly
- `MACRO`, `ENDM` - Macro definitions
- `.if`, `.else`, `.endif` - Conditional directives

**Comments**:
```asm
; Single-line comment
```

**Labels**:
```asm
LABEL:                  ; Global label
.LOCAL:                 ; Local label
```

---

### Intel HEX Format

**Structure**: ASCII text with records
```
:LLAAAATTDD...CC
```

- `LL` - Length (2 hex digits)
- `AAAA` - Address (4 hex digits)
- `TT` - Record type (00=data, 01=EOF)
- `DD...` - Data bytes
- `CC` - Checksum

**Example**:
```
:10010000C30E0121F4F5CD1D01C9210001CD2C010D
:00000001FF
```

**Usage**: cpmsim simulator loads .hex files with `-x` flag

---

## C Toolchain (SDCC)

### SDCC - Small Device C Compiler

**Purpose**: C compiler for 8-bit microcontrollers

**Version**: 4.5.0 or later

**Target**: `-mz80` (Z80/8080 subset)

**Standard**: C11 (`--std-c11`)

**Homepage**: https://sdcc.sourceforge.net/

---

### SDCC Toolchain Components

**1. sdcc - C Compiler**
- Compiles C source to relocatable object files (.rel)
- Invokes assembler and linker
- Performs optimization

**2. sdasz80 - Assembler**
- Assembles .asm files to .rel format
- Used for crt0.s (C runtime startup)

**3. sdldz80 - Linker**
- Links .rel files to Intel HEX (.ihx)
- Resolves symbols and addresses
- Produces memory map (.map)

**4. sdar - Archiver**
- Creates library archives (.lib)
- Combines multiple .rel files
- Used for libjx.lib

**5. makebin - Binary Converter**
- Converts Intel HEX to raw binary
- Used for creating .bin files from .ihx

---

### SDCC Compilation Flags

**Target Selection**:
- `-mz80` - Target Z80/8080 processor (required)

**C Standard**:
- `--std-c11` - Use C11 standard
- `--std-c99` - Use C99 standard
- `--std-c89` - Use C89/ANSI C standard

**Optimization**:
- `--opt-code-size` - Optimize for code size (recommended for 8080)
- `--opt-code-speed` - Optimize for speed

**Output Control**:
- `-c` - Compile only (don't link)
- `-o <file>` - Output file name
- `-I<dir>` - Include directory

**Debugging**:
- `--fverbose-asm` - Generate verbose assembly listings
- `--debug` - Include debug symbols

**Linker Options**:
- `--code-loc <addr>` - Code segment start address
- `--data-loc <addr>` - Data segment start address
- `--no-std-crt0` - Don't link standard crt0 (use custom)

**JX Standard Flags**:
```bash
SDCC_FLAGS = -mz80 --std-c11 --opt-code-size --fverbose-asm
```

---

### SDCC Build Process

**Step 1: Compile C to .rel**
```bash
sdcc -mz80 --std-c11 --opt-code-size -c -o hello.rel hello.c
```

**Step 2: Assemble crt0 to .rel**
```bash
sdasz80 -plosgff -o crt0.rel crt0.s
```

**Step 3: Link to .ihx**
```bash
sdcc -mz80 --std-c11 \
     --code-loc 0x0100 \
     --data-loc 0x8000 \
     --no-std-crt0 \
     -o hello.ihx \
     crt0.rel hello.rel libjx.lib
```

**Step 4: Convert to .hex/.bin**
```bash
cp hello.ihx hello.hex            # Intel HEX (for simulator)
makebin -p hello.ihx hello.bin    # Raw binary (for ROM)
```

---

### SDCC Memory Model

**Code Segment** (`--code-loc 0x0100`):
- Program instructions
- Constant data (string literals)
- Starts at TPA_BASE (0x0100)

**Data Segment** (`--data-loc 0x8000`):
- Initialized global variables
- Static variables
- Placed high to avoid conflicts

**BSS Segment**:
- Uninitialized global variables
- Zeroed at startup by crt0
- Follows DATA segment

**Heap Segment**:
- Dynamic allocations (malloc)
- Grows upward from BSS_END
- Managed by malloc.c

**Stack Segment**:
- Function call frames
- Local variables
- Grows downward from TPA_TOP

---

### SDCC Calling Convention

**Parameter Passing** (8080 target):
- First parameter: DE, BC, or stack
- Remaining parameters: stack
- Return value: HL (16-bit), L (8-bit)

**Register Usage**:
- Preserved: (none by default)
- Clobbered: All registers may be modified
- Use `__naked` for full control

**Stack Frame**:
```
SP → [Return Address]
     [Parameter N]
     ...
     [Parameter 1]
     [Local Variable 1]
     ...
```

---

### SDCC Inline Assembly

**Basic Syntax**:
```c
void my_function(void) __naked {
    __asm
        ; Assembly code here
        ret
    __endasm;
}
```

**Accessing C Variables**:
```c
uint16_t bdos(uint8_t func, uint16_t arg) __naked {
    __asm
        pop     hl              ; Return address
        pop     de              ; arg (16-bit)
        pop     bc              ; func (8-bit in C)
        push    bc
        push    de
        push    hl
        call    0x0005          ; BDOS entry
        ret                     ; Result in HL
    __endasm;
}
```

**Notes**:
- `__naked` suppresses function prologue/epilogue
- Manual stack management required
- No C variable access inside `__asm` blocks

---

## Installation

### macOS

**Install z80pack**:
```bash
# Clone repository
git clone https://github.com/udo-munk/z80pack.git
cd z80pack

# Build z80asm
cd z80asm
make
cd ..

# Build cpmsim simulator
cd cpmsim
make
cd ..

# Add to PATH (in ~/.zshrc or ~/.bash_profile)
export PATH="$PATH:/path/to/z80pack/z80asm"
export PATH="$PATH:/path/to/z80pack/cpmsim"
```

**Install SDCC**:
```bash
# Using Homebrew
brew install sdcc

# Verify installation
sdcc --version
```

---

### Linux (Ubuntu/Debian)

**Install z80pack**:
```bash
# Install dependencies
sudo apt-get update
sudo apt-get install build-essential git

# Clone and build z80pack
git clone https://github.com/udo-munk/z80pack.git
cd z80pack
cd z80asm && make && cd ..
cd cpmsim && make && cd ..

# Add to PATH (in ~/.bashrc)
export PATH="$PATH:$HOME/z80pack/z80asm"
export PATH="$PATH:$HOME/z80pack/cpmsim"
```

**Install SDCC**:
```bash
sudo apt-get install sdcc
sdcc --version
```

---

### Windows

**Install z80pack**:
1. Download from https://github.com/udo-munk/z80pack
2. Build using MinGW or WSL
3. Add to PATH

**Install SDCC**:
1. Download installer from https://sdcc.sourceforge.net/
2. Run installer
3. Add to PATH

---

## Tool Reference

### z80asm Quick Reference

```bash
# Build BIOS (raw binary at 0xFD00)
z80asm -8 -fb -l -T -sn -p0 \
       -dBIOS_BASE=0FD00H \
       -o bios.bin bios.asm

# Build test program (Intel HEX at 0x0100)
z80asm -8 -fh -l -T -sn -p0 \
       -dTPA_BASE=0100H \
       -o test.hex test.asm

# Build with symbols
z80asm -8 -fb -l -sn \
       -o program.bin program.asm
# Produces: program.bin, program.lis
```

---

### sdcc Quick Reference

```bash
# Compile C to object file
sdcc -mz80 --std-c11 --opt-code-size -c -o file.rel file.c

# Assemble to object file
sdasz80 -plosgff -o file.rel file.s

# Create library archive
sdar -rc libjx.lib file1.rel file2.rel file3.rel

# Link program
sdcc -mz80 --code-loc 0x0100 --data-loc 0x8000 \
     --no-std-crt0 -o program.ihx \
     crt0.rel program.rel libjx.lib

# Convert to binary
makebin -p program.ihx program.bin

# Full build (one command)
sdcc -mz80 --std-c11 --opt-code-size \
     --code-loc 0x0100 --data-loc 0x8000 \
     --no-std-crt0 -o program.ihx \
     crt0.rel program.c libjx.lib
```

---

### cpmsim Quick Reference

```bash
# Run Intel HEX file
cpmsim -8 -m 00 -x program.hex

# Flags:
#   -8     : 8080 mode
#   -m 00  : Initialize memory to 0x00
#   -x     : Load Intel HEX file

# Exit simulator: Ctrl+C or program exit
```

---

## Build Workflow

### Assembly Program Workflow

```
source.asm
    ↓
z80asm -8 -fb
    ↓
source.bin (raw binary)
    ↓
cpmsim (load to memory)
    ↓
Run program
```

**Example**:
```bash
# Build
z80asm -8 -fb -dTPA_BASE=0100H -o hello.bin hello.asm

# Run
cpmsim -8 -m 00 -x hello.bin
```

---

### C Program Workflow

```
program.c
    ↓
sdcc -c (compile)
    ↓
program.rel
    ↓                    crt0.s → sdasz80 → crt0.rel
    ↓                    libjx.lib
    ↓                    ↓
sdcc (link) ←────────────┴
    ↓
program.ihx (Intel HEX)
    ↓
    ├── cp → program.hex (for simulator)
    └── makebin → program.bin (raw binary)
    ↓
cpmsim -x program.hex
    ↓
Run program
```

**Example**:
```bash
# Build C library
make $(BUILD_DIR)/libjx.lib

# Build program
make $(BUILD_DIR)/examples/hello.hex

# Run
make run-example EXAMPLE=hello
```

---

### System Image Workflow

```
src/ccp/ccp.c → SDCC → ccp.bin (at 0x0100)
src/bdos/bdos.asm → z80asm → bdos.bin (at 0xF600)
src/bios/bios.asm → z80asm → bios.bin (at 0xFE00)
    ↓           ↓           ↓
    └───────────┴───────────┘
              cat
              ↓
          jx.bin (system image)
              ↓
          cpmsim -x
              ↓
      Boot JX Operating System
```

**Example**:
```bash
# Build complete system
make all

# Run system
make run
```

---

## Troubleshooting

### z80asm Issues

**Error: "Unsupported directive"**
- **Cause**: Using IFNDEF, IFDEF, MACRO, etc.
- **Fix**: Remove conditional directives, use manual editing

**Error: "Illegal instruction"**
- **Cause**: Z80-only instruction in 8080 mode
- **Fix**: Use only 8080 instructions when `-8` flag is set

**Listing file not generated**
- **Cause**: Missing `-l` flag
- **Fix**: Add `-l` to command line

---

### SDCC Issues

**Error: "undefined reference to '_main'"**
- **Cause**: No main() function defined
- **Fix**: Add `int main(void) { ... }`

**Error: "undefined reference to '_printf'"**
- **Cause**: libjx.lib not linked
- **Fix**: Add `$(LIBJX)` to link command

**Error: "area overflow"**
- **Cause**: Program too large for memory
- **Fix**: Reduce code size, use `--opt-code-size`

**Warning: "stack allocation"**
- **Cause**: Large local variables
- **Fix**: Use malloc() or reduce variable size

**Error: "can't open crt0.rel"**
- **Cause**: crt0 not built
- **Fix**: Build crt0 first: `make $(CRT0_REL)`

---

### Simulator Issues

**cpmsim: "can't load file"**
- **Cause**: File doesn't exist or wrong format
- **Fix**: Check file path, use .hex for `-x` flag

**Program doesn't output**
- **Cause**: BDOS not responding
- **Fix**: Verify BDOS is loaded at 0xF600

**Simulator hangs**
- **Cause**: Infinite loop or HALT instruction
- **Fix**: Use Ctrl+C to exit, check program logic

---

### Build System Issues

**Make: "z80asm: command not found"**
- **Cause**: z80pack not in PATH
- **Fix**: Check `config.mk` Z80PACK_DIR setting

**Make: "sdcc: command not found"**
- **Cause**: SDCC not installed or not in PATH
- **Fix**: Install SDCC, verify with `which sdcc`

**Make: "No rule to make target"**
- **Cause**: Missing dependency or typo
- **Fix**: Check file names, run `make clean`

---

## Output File Formats

### .bin (Raw Binary)

- Pure machine code
- No headers or metadata
- Used for ROM images
- Loaded at specific address

**Tools**: z80asm `-fb`, makebin

---

### .hex (Intel HEX)

- ASCII text format
- Includes load addresses
- Portable across systems
- Used for simulator

**Tools**: z80asm `-fh`, sdcc (produces .ihx)

---

### .rel (Relocatable Object)

- SDCC object file format
- Contains unresolved symbols
- Linked by sdldz80
- Intermediate format

**Tools**: sdcc `-c`, sdasz80

---

### .lib (Library Archive)

- Collection of .rel files
- Created by sdar
- Linked as needed
- Example: libjx.lib

**Tools**: sdar

---

### .lis (Listing File)

- Assembly listing with addresses
- Shows machine code + source
- Includes symbol table
- Used for debugging

**Tools**: z80asm `-l`

---

### .map (Memory Map)

- Shows memory layout
- Symbol addresses
- Segment sizes
- Produced by linker

**Tools**: sdldz80

---

## Advanced Topics

### Custom Memory Layouts

**Modify link addresses**:
```bash
sdcc --code-loc 0x0200 \      # Start code higher
     --data-loc 0x9000 \      # Move data segment
     ...
```

**Use case**: Special memory configurations

---

### Library Creation

**1. Compile sources**:
```bash
sdcc -c -o file1.rel file1.c
sdcc -c -o file2.rel file2.c
```

**2. Create archive**:
```bash
sdar -rc mylib.lib file1.rel file2.rel
```

**3. Link with library**:
```bash
sdcc -o program.ihx program.rel mylib.lib
```

---

### Optimization Techniques

**Code Size**:
- Use `--opt-code-size`
- Minimize printf usage (use puts)
- Share common code via functions
- Use local variables (stack) not global

**Speed**:
- Use `--opt-code-speed`
- Inline critical functions
- Reduce function call overhead
- Use lookup tables

---

## Version Information

**Recommended Versions**:
- z80pack: 1.36 or later
- SDCC: 4.5.0 or later
- cpmsim: Latest from z80pack

**Compatibility**:
- Older SDCC versions may work but are untested
- z80pack 1.36 has known issues with conditional directives

---

## See Also

- **Build System**: `BUILD_SYSTEM.md`
- **C Programming**: `PROGRAMMING_C.md`
- **C Library**: `C_LIBRARY.md`
- **CCP Shell**: `CCP_GUIDE.md`

---

## External Resources

**SDCC Documentation**:
- Manual: https://sdcc.sourceforge.net/doc/sdccman.pdf
- Wiki: https://sdcc.sourceforge.net/mediawiki/index.php

**z80pack**:
- Repository: https://github.com/udo-munk/z80pack
- Documentation: Included in distribution

**Intel 8080**:
- Instruction Set: https://pastraiser.com/cpu/i8080/i8080_opcodes.html
- Programming Manual: Available online

---

*Last Updated: 2026-01-29*
*JX Operating System - Toolchain Guide*
