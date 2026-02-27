# JX Monitor

A machine-language monitor for Intel 8080, written entirely in 8080 assembly. Provides interactive memory inspection, testing, and program execution. Runs on the z80pack simulator and targets Altair/IMSAI-style hardware.

## Features

- Pure Intel 8080 assembly -- no C compiler required
- Interactive monitor with hex dump, memory test, write, go, and I/O port commands
- Dual output: serial console AND VDM-1 memory-mapped video display
- Memory detection at boot (32KB--64KB)
- Single flat binary (~3.5KB with video, ~3.1KB serial-only), assembled from one source file
- Builds to Intel HEX for direct simulator loading

## Quick Start

### Prerequisites

- **z80pack** (z80asm assembler and cpmsim simulator)
- **GNU Make**

Build z80pack from https://github.com/udo-munk/z80pack if not already installed.

### Building and Running

```bash
git clone <repository-url>
cd jx

# Edit config.mk to set Z80PACK_DIR if needed
vi config.mk

# Build and run
make run
```

## Monitor Commands

```
> ?

JX Monitor Commands:
  d <addr> [<end>]    Hex dump memory
  t [<start> <end>]   RAM test (destructive)
  w <addr> <bb> ..    Write bytes
  g <addr>            Go (execute)
  in <port>           Read I/O port
  out <port> <byte>   Write I/O port
  l <port>            Load Intel HEX (1=con, 2=aux)
  m                   Memory info
  cls                 Clear screen
  ? or help           This message
```

All addresses and byte values are hexadecimal.

### Example Session

```
JX/8080 Monitor v0.4
Scanning: ********
Memory: 64KB
Video: VDM-1 64x16 at C000

Type ? for help.
> d F400 F40F
F400: F3 31 00 F4 21 D1 FD CD  D1 F4 21 F8 FD CD D1 F4  .1..!.....!.....
> w 0100 C3 00 00
> g 0100
```

## Memory Layout (64KB)

```
0000-00FF  Page Zero (JMP MONITOR at 0000H)
0100-BFFF  Free RAM (~48KB)
C000-C3FF  VDM-1 video framebuffer (64x16)
F400-FFFF  Monitor (~3.5KB)
```

Programs loaded at 0100H can return to the monitor via `JMP 0000H`.

## Hardware

### Serial Console
- cpmsim console ports: status on port 0, data on port 1
- Directly connected to the host terminal via the simulator

### Video Display
- Processor Technology VDM-1 (optional, enabled by default)
- 64 columns x 16 rows, memory-mapped at C000H-C3FFH
- Software scrolling, cursor tracking
- All monitor output goes to both serial and video simultaneously

## Build System

```bash
make            # Build monitor (Intel HEX)
make run        # Build and run in simulator
make clean      # Remove build artifacts
make info       # Show configuration
make help       # Show build targets
```

### Memory Configurations

```bash
make MEM_SIZE=32    # Monitor at 7400H
make MEM_SIZE=48    # Monitor at B400H
make MEM_SIZE=64    # Monitor at F400H (default)
```

### Disabling Video

```bash
make VIDEO_BASE=0   # Serial-only build
```

## Project Structure

```
jx/
├── Makefile            Build rules
├── config.mk           Toolchain paths and hardware options
├── src/
│   ├── bios/
│   │   ├── bios.asm    System entry point (includes everything)
│   │   ├── serial.asm  Serial console driver
│   │   └── video.asm   VDM-1 video driver
│   ├── lib/
│   │   ├── print.asm   Output formatting (hex, decimal, strings)
│   │   └── string.asm  String operations (strlen, strcmp, etc.)
│   └── monitor.asm     Monitor command processor
├── scripts/
│   └── run-boot.sh     Build and run helper
├── docs/
│   ├── BUILD_SYSTEM.md Build system reference
│   ├── TOOLCHAIN.md    Assembler and simulator reference
│   └── Z80ASM_BUGS.md  Known z80asm issues
├── DESIGN.md           Architecture specification
└── build/              Output directory (generated)
    └── jx.hex          Monitor binary (Intel HEX)
```

## Documentation

- **[Build System](docs/BUILD_SYSTEM.md)** -- Build configuration and targets
- **[Toolchain](docs/TOOLCHAIN.md)** -- Assembler syntax and simulator usage
- **[z80asm Bugs](docs/Z80ASM_BUGS.md)** -- Known assembler quirks
- **[Design](DESIGN.md)** -- Architecture and memory layout

## Toolchain

- **Assembler**: z80asm from z80pack (8080 mode, `-8 -e32`)
- **Output**: Intel HEX format (.hex)
- **Simulator**: cpmsim from z80pack

## Known Issues

The z80asm assembler (v2.1 from z80pack) has several quirks:
- Default symbol length is 8 characters; use `-e32` for longer names
- `INCLUDE` filenames must not be quoted
- `INCLUDE` resolves relative to CWD, not the source file
- Conditional directives (`IF`, `ENDIF`) must not start in column 1

See `docs/Z80ASM_BUGS.md` for details.

## Credits

- **z80pack**: Udo Munk (https://github.com/udo-munk/z80pack)
- **Intel 8080**: Classic 8-bit microprocessor architecture

---

*JX Monitor -- Pure Intel 8080 Assembly*
