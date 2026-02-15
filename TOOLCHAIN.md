# JX Monitor -- Toolchain Reference

Development toolchain for building and running the JX monitor for Intel 8080.

---

## 1. Overview

| Tool | Purpose |
|------|---------|
| z80asm | Cross-assembler (8080 mode) from z80pack |
| cpmsim | 8080 simulator from z80pack |
| GNU Make | Build automation |

The entire monitor is pure Intel 8080 assembly. No C compiler is required.

---

## 2. Prerequisites

### 2.1 Installing z80pack

```bash
git clone https://github.com/udo-munk/z80pack
cd z80pack

# Build assembler
cd z80asm && make && cd ..

# Build simulator
cd cpmsim/srcsim && make && cd ../..
```

### 2.2 Verifying Installation

```bash
# Check assembler
/path/to/z80pack/z80asm/z80asm
# Should display usage

# Check simulator
/path/to/z80pack/cpmsim/cpmsim -h
# Should display help

# Or via the build system
make check-tools
```

---

## 3. Configuration (config.mk)

```makefile
Z80PACK_DIR = ../z80pack        # Path to z80pack installation
MEM_SIZE    = 64                # Memory: 32, 48, or 64 KB
VIDEO_BASE  = 0C000H           # VDM-1 address (0 = disabled)
VIDEO_COLS  = 64               # VDM-1 columns
VIDEO_ROWS  = 16               # VDM-1 rows
```

---

## 4. Assembler (z80asm)

### 4.1 Flags

| Flag | Purpose |
|------|---------|
| `-8` | 8080 mode -- reject Z80-only instructions |
| `-e32` | Allow symbol names up to 32 characters |
| `-l` | Generate listing file (.lis) |
| `-T` | Omit symbol table from listing |
| `-sn` | Output symbol table sorted numerically |
| `-p0` | Fill unused memory with 00H |
| `-fh` | Output Intel HEX format |
| `-fb` | Output flat binary format |

### 4.2 Assembler Invocation

```bash
z80asm -8 -e32 -fh -l -T -sn -p0 \
       -dBIOS_BASE=0F400H -dMEM_SIZE=64 \
       -dVIDEO_BASE=0C000H -dVIDEO_COLS=64 -dVIDEO_ROWS=16 \
       -o build/jx.hex bios.asm
```

The Makefile `cd`s into `src/bios/` before invoking z80asm so that `INCLUDE` directives resolve relative to the source directory.

### 4.3 Syntax

```asm
; Comments start with semicolon
LABEL:                          ; Labels end with colon (column 1)
        MVI     A,42H           ; Instructions indented
        OUT     01H

CONSTANT EQU    1234H           ; Constant definition
VARIABLE DB     0               ; Define byte
STRING   DB     'Hello',0       ; Null-terminated string
BUFFER   DS     128             ; Reserve 128 bytes
```

### 4.4 Numeric Formats

| Format | Example | Value |
|--------|---------|-------|
| Decimal | `123` | 123 |
| Hexadecimal | `0ABH` | 171 |
| Binary | `10101010B` | 170 |
| Character | `'A'` | 65 |

Hex numbers starting with A-F must have a leading `0` (e.g., `0FE00H` not `FE00H`).

### 4.5 Directives

| Directive | Example | Notes |
|-----------|---------|-------|
| `ORG` | `ORG 0F400H` | Set origin address |
| `EQU` | `CR EQU 0DH` | Define constant |
| `DB` | `DB 'Hello',0` | Define bytes |
| `DW` | `DW 1234H` | Define words |
| `DS` | `DS 256` | Reserve space |
| `IF` / `ENDIF` | `IF VIDEO_BASE` | Conditional assembly |
| `INCLUDE` | `INCLUDE serial.asm` | Include source file |
| `END` | `END` | End of source |

### 4.6 Important z80asm Quirks

1. **Symbol length**: Default is 8 characters. Symbols longer than 8 chars are truncated, causing "multiple defined symbol" errors for symbols with the same prefix. Always use `-e32`.

2. **INCLUDE syntax**: Filenames must NOT be quoted. Use `INCLUDE serial.asm`, not `INCLUDE "serial.asm"`. Quotes become part of the filename.

3. **INCLUDE path resolution**: Resolves relative to the current working directory, NOT relative to the source file. The Makefile handles this by `cd`ing into the source directory.

4. **Column 1 = labels**: Any token starting in column 1 is treated as a label. Directives like `IF`, `ENDIF`, `IFNDEF` must be indented (e.g., 8 spaces) or they will be parsed as label names.

See `docs/Z80ASM_BUGS.md` for additional known issues.

### 4.7 8080 Instruction Set Summary

**Data Transfer**: MOV, MVI, LXI, LDA, STA, LHLD, SHLD, LDAX, STAX, XCHG

**Arithmetic/Logic**: ADD, ADI, ADC, ACI, SUB, SUI, SBB, SBI, INR, DCR, INX, DCX, DAD, ANA, ANI, ORA, ORI, XRA, XRI, CMP, CPI, RLC, RRC, RAL, RAR, CMA, CMC, STC, DAA

**Branch**: JMP, JZ, JNZ, JC, JNC, JP, JM, JPE, JPO, CALL, CZ, CNZ, CC, CNC, RET, RZ, RNZ, RC, RNC, PCHL, RST

**Stack/I/O/Control**: PUSH, POP, XTHL, SPHL, IN, OUT, EI, DI, HLT, NOP

---

## 5. Simulator (cpmsim)

### 5.1 Invocation

```bash
cpmsim -8 -m 00 -x build/jx.hex
```

| Flag | Purpose |
|------|---------|
| `-8` | 8080 CPU mode |
| `-m 00` | Initialize memory to 00H |
| `-x file` | Load Intel HEX file and execute from its start address |
| `-f N` | CPU frequency in MHz |

### 5.2 I/O Port Map

| Port | Read | Write |
|------|------|-------|
| 0 | Console status (00=no char, FF=ready) | -- |
| 1 | Console data (receive) | Console data (transmit) |
| 10-16 | Disk I/O (not used by JX) | Disk I/O |

### 5.3 Running

```bash
# Via Make
make run

# Via helper script
./scripts/run-boot.sh

# Direct invocation
cpmsim -8 -m 00 -x build/jx.hex
```

Exit the simulator with Ctrl-\ (SIGQUIT).

---

## 6. Build System

### 6.1 Targets

| Target | Description |
|--------|-------------|
| `make` / `make all` | Build monitor (Intel HEX) |
| `make run` | Build and run in simulator |
| `make clean` | Remove build artifacts |
| `make distclean` | Remove build directory |
| `make info` | Show configuration |
| `make help` | Show available targets |

### 6.2 Build Options

```bash
make MEM_SIZE=32        # Build for 32KB
make MEM_SIZE=48        # Build for 48KB
make MEM_SIZE=64        # Build for 64KB (default)
make VIDEO_BASE=0       # Disable video
```

### 6.3 Output Files

| File | Format | Purpose |
|------|--------|---------|
| `build/jx.hex` | Intel HEX | Simulator input (primary output) |
| `src/bios/bios.lis` | Listing | Debug: addresses, opcodes, source |

---

## 7. Memory Configurations

```
      32KB                    48KB                    64KB
  ┌──────────┐ 7FFF      ┌──────────┐ BFFF      ┌──────────┐ FFFF
  │ Monitor  │           │ Monitor  │           │ Monitor  │
  ├──────────┤ 7400      ├──────────┤ B400      ├──────────┤ F400
  │          │           │          │           │  Video   │ C3FF
  │ Free RAM │           │ Free RAM │           ├──────────┤ C000
  │          │           │          │           │ Free RAM │
  ├──────────┤ 0100      ├──────────┤ 0100      ├──────────┤ 0100
  │ Page 0   │           │ Page 0   │           │ Page 0   │
  └──────────┘ 0000      └──────────┘ 0000      └──────────┘ 0000
```

Video (VDM-1 at C000H) is only relevant for 64KB systems.

---

## 8. Troubleshooting

### "invalid opcode"
- Z80 instruction used in 8080 mode (e.g., `LD` instead of `MOV`)
- Or: a directive (`IF`, `ENDIF`) starting in column 1 was parsed as a label

### "undefined symbol"
- Check spelling
- Ensure INCLUDE files are present
- Verify assembler CWD matches source directory

### "multiple defined symbol"
- Symbol names sharing the same first 8 characters collide
- Add `-e32` to assembler flags (already in config.mk)

### Simulator loads 0 bytes
- Output must be Intel HEX (`-fh`), not flat binary (`-fb`)
- cpmsim's `-x` flag expects `:` records (Intel HEX format)

### No output from monitor
- Check serial port definitions (should be port 0 for status, port 1 for data)
- Verify the HEX file has the correct ORG address

---

*Last Updated: 2026-02-13*
