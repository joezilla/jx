# JX Monitor

A machine-language monitor and BASIC interpreter for Intel 8080, written entirely in 8080 assembly. Provides interactive memory inspection, testing, program execution, and Altair BASIC 3.2. Runs on the z80pack simulator and targets Altair/IMSAI-style hardware.

## Features

- Pure Intel 8080 assembly -- no C compiler required
- Altair BASIC 3.2 (4K edition) -- standalone boot or loadable via monitor
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

## Altair BASIC

JX includes Altair BASIC 3.2 (4K edition) by Bill Gates, Paul Allen, and Monte Davidoff. This is the numeric-only version -- no string variables (`A$`), only numeric (`A`, `A1`, etc.).

When `ENABLE_BASIC=1` (the default), `make run` boots directly into BASIC:

```
MEMORY SIZE?
TERMINAL WIDTH?
WANT SIN? N
WANT RND? N
WANT SQR? N

3029 BYTES FREE

BASIC VERSION 3.2
[4K VERSION]

OK
PRINT 2+2
 4

OK
```

Press Enter at MEMORY SIZE? and TERMINAL WIDTH? to accept defaults. Answering Y to SIN/RND/SQR includes those math functions (uses more memory).

### BASIC Build Targets

```bash
make basic           # Build standalone BASIC (boots directly)
make basic-loadable  # Build loadable BASIC (load via monitor 'l' command)
make run-basic       # Build and run standalone BASIC in simulator
make run             # Same as run-basic when ENABLE_BASIC=1
make disk            # Create boot disk image
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
make run        # Build and run in simulator (BASIC if enabled)
make basic      # Build standalone BASIC
make disk       # Create boot disk image
make test       # Run test suite
make clean      # Remove build artifacts
make info       # Show configuration
make help       # Show build targets
```

### Using an Alternate Config

Two configs are provided: `config.mk` (IMSAI hardware) and `config.mk.sim` (cpmsim simulator). Override with `CONFIG=`:

```bash
make run CONFIG=config.mk.sim
```

## Configuration (config.mk)

All hardware and build options are set in `config.mk`. Key settings:

| Option | Default (IMSAI) | Simulator | Description |
|--------|-----------------|-----------|-------------|
| `SIO_DATA` | `12H` | `01H` | Serial data port |
| `SIO_STATUS` | `13H` | `00H` | Serial status port |
| `SIO_RX_MASK` | `02H` | `0FFH` | RX ready bitmask |
| `SIO_TX_MASK` | `01H` | `0` | TX ready bitmask (0 = no poll) |
| `SIO_8251` | `1` | `0` | Enable 8251 USART init sequence |
| `MEM_SIZE` | `48` | `64` | RAM size in KB (32, 48, or 64) |
| `BIOS_BASE` | `0` | `0` | Monitor ORG address (0 = flat binary) |
| `VIDEO_BASE` | `0CC00H` | `0` | VDM-1 base address (0 = disabled) |
| `ENABLE_BASIC` | `1` | `1` | Include Altair BASIC (0 or 1) |
| `ENABLE_TERM` | `0` | `0` | Include terminal mode (0 or 1) |

Secondary serial port (`SIO2_*`) and video geometry (`VIDEO_COLS`, `VIDEO_ROWS`, `VIDEO_CTRL`) are also configurable. See `config.mk` for the full list.

## Project Structure

```
jx/
├── Makefile            Build rules
├── config.mk           Hardware config (IMSAI)
├── config.mk.sim       Hardware config (cpmsim simulator)
├── src/
│   ├── bios/
│   │   ├── bios.asm    System entry point (includes everything)
│   │   ├── serial.asm  Serial console driver
│   │   └── video.asm   VDM-1 video driver
│   ├── basic/
│   │   ├── altair_basic.asm       Altair BASIC 3.2 (4K)
│   │   ├── basic_standalone.asm   Standalone entry point
│   │   └── basic_loadable.asm     Loadable entry point
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

*JX Monitor + Altair BASIC -- Pure Intel 8080 Assembly*
