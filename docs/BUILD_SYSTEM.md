# JX Monitor -- Build System Guide

## Overview

The JX build system uses GNU Make with a single tool: **z80asm** from z80pack. The entire monitor is one assembly source file (`src/bios/bios.asm`) that INCLUDEs all sub-modules. The output is a single Intel HEX file.

### Build Files

| File | Purpose |
|------|---------|
| `Makefile` | Build rules and targets |
| `config.mk` | Toolchain paths, memory size, hardware options |

---

## Configuration

### config.mk

```makefile
Z80PACK_DIR = ../z80pack       # z80pack installation
MEM_SIZE    = 64               # 32, 48, or 64 KB
VIDEO_BASE  = 0C000H           # VDM-1 address (0 to disable)
VIDEO_COLS  = 64               # VDM-1 columns
VIDEO_ROWS  = 16               # VDM-1 rows
```

### Assembler Flags

```makefile
ASM_FLAGS_COMMON = -8 -e32 -l -T -sn -p0
ASM_FLAGS_HEX = $(ASM_FLAGS_COMMON) -fh
```

| Flag | Purpose |
|------|---------|
| `-8` | 8080 instruction set only |
| `-e32` | 32-character symbol names (default is 8) |
| `-l` | Generate listing file |
| `-T` | Omit symbol table from listing |
| `-sn` | Sort symbols numerically |
| `-p0` | Fill unused bytes with 00H |
| `-fh` | Intel HEX output format |

---

## Build Targets

```bash
make            # Build monitor (default)
make run        # Build and run in cpmsim
make clean      # Remove build artifacts
make distclean  # Remove build directory
make info       # Show current configuration
make help       # Show available targets
make check-tools  # Verify z80asm is installed
```

### Build Options

```bash
make MEM_SIZE=32        # 32KB system (monitor at 7400H)
make MEM_SIZE=48        # 48KB system (monitor at B400H)
make MEM_SIZE=64        # 64KB system (monitor at F400H, default)
make VIDEO_BASE=0       # Disable VDM-1 video support
```

---

## Build Process

```
src/bios/bios.asm
  INCLUDE serial.asm          Serial console driver
  INCLUDE video.asm           VDM-1 video driver
  INCLUDE ../lib/print.asm    Output formatting
  INCLUDE ../lib/string.asm   String operations
  INCLUDE ../monitor.asm      Monitor commands
        │
        ▼
    z80asm -8 -e32 -fh ...
        │
        ├──> build/jx.hex      Intel HEX (primary output)
        └──> src/bios/bios.lis  Assembly listing
```

The Makefile `cd`s into `src/bios/` before invoking z80asm so that INCLUDE paths resolve relative to the source file's directory.

### Assembler Defines

The build system passes configuration via `-d` flags:

```
-dBIOS_BASE=0F400H     Monitor load address
-dMEM_SIZE=64           Memory size in KB
-dVIDEO_BASE=0C000H    Video framebuffer address
-dVIDEO_COLS=64         Video columns
-dVIDEO_ROWS=16         Video rows
```

---

## Memory Layout

### 64KB (default)

```
0000-00FF  Page Zero (JMP MONITOR)
0100-BFFF  Free RAM (~48KB)
C000-C3FF  VDM-1 video framebuffer
F400-FFFF  Monitor (~3.5KB)
```

### 48KB

```
0000-00FF  Page Zero
0100-B3FF  Free RAM (~45KB)
B400-BFFF  Monitor (~3.5KB)
```

### 32KB

```
0000-00FF  Page Zero
0100-73FF  Free RAM (~29KB)
7400-7FFF  Monitor (~3.5KB)
```

---

## Source Files

```
src/
├── bios/
│   ├── bios.asm        Entry point, boot, PUTCHAR, GETCHAR, MEMPROBE
│   ├── serial.asm      Console driver (ports 0/1)
│   └── video.asm       VDM-1 driver (C000H, 64x16)
├── lib/
│   ├── print.asm       PRINTS, PRCRLF, PRHEX8, PRHEX16, PRDEC8, PRDEC16
│   └── string.asm      STRLEN, STRCMP, STRCPY, STRTOUPPER
└── monitor.asm         Command loop, DUMP, TEST, WRITE, GO, MEM, CLS, HELP
```

### Assembly Library (src/lib/)

| File | Routines | Purpose |
|------|----------|---------|
| `print.asm` | PRINTS, PRCRLF, PRHEX8, PRHEX16, PRNIB, PRDEC8, PRDEC16 | Output formatting |
| `string.asm` | STRLEN, STRCMP, STRCPY, STRTOUPPER | String operations |

All print routines call `PUTCHAR` (defined in bios.asm), which outputs to both serial and video.

---

## Output

| File | Format | Description |
|------|--------|-------------|
| `build/jx.hex` | Intel HEX | Monitor binary with load address |
| `src/bios/bios.lis` | Listing | Addresses, opcodes, source lines |

The listing file is generated in the source directory (alongside bios.asm) because z80asm places it next to the source file.

---

## Troubleshooting

### "multiple defined symbol"
Symbols with the same first 8 characters collide. The `-e32` flag in config.mk prevents this. If you see this error, verify `-e32` is present in ASM_FLAGS_COMMON.

### "can't open file"
INCLUDE resolves relative to CWD. The Makefile handles this by `cd`ing into `src/bios/`. If building manually, run z80asm from the `src/bios/` directory.

### Build output too large
The monitor must fit between BIOS_BASE and FFFFH. For 64KB that is 3072 bytes (F400-FFFF). Check the listing file for the final address to verify the binary fits.

### Simulator loads nothing
cpmsim's `-x` flag requires Intel HEX format. Flat binary (`-fb`) files have no address metadata and load 0 bytes.

---

## See Also

- `TOOLCHAIN.md` -- Assembler and simulator reference
- `docs/Z80ASM_BUGS.md` -- Known z80asm quirks
- `DESIGN.md` -- Architecture specification

---

*Last Updated: 2026-02-13*
