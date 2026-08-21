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
F400: F3 31 00 F4 21 D1 FD CD  D1 F4 21 F8 FD CD D1 F4 
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

## Memory Layout

The default build loads the monitor at address 0000H (`BIOS_BASE=0`):

```
0000-xxxx  Monitor code + data (~3.5KB)
xxxx-FFFF  Free RAM
C000-C3FF  VDM-1 video framebuffer (64x16), if enabled
```

Setting `BIOS_BASE` to a nonzero address relocates the monitor and
splits it into a ROM-resident code segment plus a separate `DATA_BASE`
RAM segment for mutable state, so it can be burned into a real EPROM
(e.g. on an 88-2SIOJP board) and booted without any code needing to
live at address 0000H -- see "ROM / EPROM Builds" below and
`DESIGN.md` section 3 for the full layout.

Programs loaded at 0100H can return to the monitor via `JMP 0000H`.

## Hardware

### Serial Console

Three serial configurations are supported (select via config files):

| Config | UART Chip | Data/Status Ports | RX Mask | TX Mask | Init |
|--------|-----------|-------------------|---------|---------|------|
| cpmsim | None | 01H / 00H | FFH | 0 (no poll) | None |
| IMSAI SIO-2 | Intel 8251 | 12H / 13H | 02H (bit 1) | 01H (bit 0) | `SIO_8251=1` |
| Altair 88-2SIO | Motorola 6850 | 11H / 10H | 01H (bit 0) | 02H (bit 1) | `SIO_6850=1` |

The 8251 and 6850 have opposite RX/TX mask bit assignments. Both are auto-initialized at boot when their respective flag is set. Port addresses and masks are fully configurable via `SIO_DATA`, `SIO_STATUS`, `SIO_RX_MASK`, and `SIO_TX_MASK`.

### Video Display
- Processor Technology VDM-1 (optional, enabled by default)
- 64 columns x 16 rows, memory-mapped at C000H-C3FFH
- Software scrolling, cursor tracking
- All monitor output goes to both serial and video simultaneously

### ROM / EPROM Builds

The monitor can be relocated off address 0000H and burned into a real
EPROM -- e.g. a 2764 (8K) on an 88-2SIOJP board -- and booted via that
board's hardware "Jump-Start" feature, which redirects the CPU to
`BIOS_BASE` on reset without needing any code at 0000H.

```bash
make CONFIG=config.mk.rom          # Build for a real EPROM
make CONFIG=config.mk.sim.rom run  # Test the relocated build under cpmsim
```

See `.claude/skills/88-2SIOJP.skill.md` for EPROM socket/Jump-Start
switch settings and `DESIGN.md` section 3 for the ROM-capable memory
layout.

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

Several configs are provided. Each contains all three serial presets as comments -- uncomment the one matching your hardware:

| Config | Default Preset | Description |
|--------|---------------|-------------|
| `config.mk` | Altair 88-2SIO | Primary config (real hardware) |
| `config.mk.sim` | cpmsim | Simulator (no UART init, no TX poll) |
| `config.mk.sio` | Altair 88-2SIO | Alternate Altair config |
| `config.mk.rom` | 88-2SIOJP (6850) | ROM-capable build, monitor relocated off 0000H |
| `config.mk.sim.rom` | cpmsim | Simulator-testable variant of `config.mk.rom` |

Override with `CONFIG=`:

```bash
make run CONFIG=config.mk.sim
```

The build depends on the config file itself, so changing a config value
(and nothing else) still forces a reassembly. Switching `CONFIG=` between
builds without `make clean` is safe.

## Testing

### cpmsim (Expect suite)

```bash
make test                       # Build matrix + functional tests
expect -f tests/test-boot.exp   # Single test (after: make hex CONFIG=config.mk.sim)
```

The suite builds three configs x three targets, then drives cpmsim through
`tests/harness.exp`. See `tests/run-tests.sh`.

### BitsBy8 (virtual S-100 machine)

[BitsBy8](https://github.com/joezilla/fdcplus-web) serves disk images to a
real Altair over serial and boots fully virtual S-100 machines in the
browser. It is the closest thing to the real board short of burning an
EPROM: the monitor runs against emulated cards (6850 ACIA, VDM-1, EPROM
socket) with the same port and memory decoding as the hardware, so it
catches port/base-address mistakes that cpmsim cannot.

A machine profile assembles the cards. The ROM build is exercised by
**JX Monitor ROM Test - 88-2SIOJP**:

| Card | Config |
|------|--------|
| `cpu` (`i8080-cpu`) | resetVector `E000H` -- stands in for Jump-Start |
| `ramLow` (`ram-card`) | `0000H`, 51K (covers `DATA_BASE` and the stack) |
| `video` (`vdm-1-video`) | base `CC00H`, dstatPort `C8H` |
| `ramMid` (`ram-card`) | `D000H`, 4K |
| `eeprom` (`eprom-card`) | base `E000H`, 8K (the 2764/28C64 window) |
| `sio` (`mits-88-2sio`) | basePort `10H` -- status `10H`/`12H`, data `11H`/`13H` |

Card and profile settings must agree with the config the ROM was built
from: `BIOS_BASE`/`EEPROM_SIZE` with the EPROM card, `VIDEO_BASE`/
`VIDEO_CTRL` with the VDM-1 card, and `SIO_STATUS`/`SIO_DATA` with the
2SIO card's `basePort` (the 6850 puts control/status at the even address
and data at the odd one, so `SIO_STATUS` = basePort and `SIO_DATA` =
basePort+1).

### Test loop

BitsBy8 exposes an MCP server (stdio or HTTP), so the whole cycle runs
from an AI assistant or a script without touching the web UI:

1. `make CONFIG=config.mk.rom` -- build `build/jx.bin`
2. `burn_eprom` -- load the image into the profile's `eeprom` card with
   `addressing: "base"`. This writes a **new profile version**; earlier
   versions stay resolvable, so a bad image is never destructive.
3. `create_transient_instance` with the new `profileRef` -- creates and
   boots a memory-only instance
4. `read_instance_console` / `write_instance_console` -- check the banner
   and drive the monitor (send a real `CR`, not the two characters `\r`)
5. `destroy_machine_instance` -- transients leave no residue

Useful companions: `list_machine_profiles`, `get_machine_profile`,
`validate_machine_profile` (reports port/IRQ/memory collisions and the
resolved memory map before you boot), `get_card_detail` (a card's port
footprint and programming notes), and `list_machine_instances`.

Everything above is also on the REST API (`/api/profiles/{id}/cards/{cardId}/burn`,
`/api/instances/{id}/console`, ...) with `Authorization: Bearer <api-key>`;
OpenAPI docs at `/api/docs`.

A healthy boot on the profile above:

```
JX/8080 Version 0.9
SIO 11/10 RX=01 TX=02 6850
Video: VDM-1 64x16 at CC00
  E000-F3EE  Monitor
```

The `SIO` line echoes the assembled data/status ports -- the fastest way to
tell whether the running image was built from the config you think it was.

## Configuration (config.mk)

All hardware and build options are set in `config.mk`. To switch serial hardware, comment out the active preset and uncomment another. Key settings:

### Serial Options

| Option | Description |
|--------|-------------|
| `SIO_DATA` | Serial data port address |
| `SIO_STATUS` | Serial status port address |
| `SIO_RX_MASK` | Bitmask for RX ready in status register |
| `SIO_TX_MASK` | Bitmask for TX ready (0 = no TX poll, fire-and-forget) |
| `SIO_8251` | Enable Intel 8251 USART init sequence at boot |
| `SIO_6850` | Enable Motorola 6850 ACIA init sequence at boot |

Secondary serial port (`SIO2_*`) uses the same options with the `SIO2_` prefix.

### General Options

| Option | Default | Description |
|--------|---------|-------------|
| `MEM_SIZE` | `48` | RAM size in KB (32, 48, or 64) |
| `BIOS_BASE` | `0` | Monitor ORG address (0 = flat binary at address 0; >0 = ROM-capable, relocated) |
| `DATA_BASE` | `0100H` | RAM data segment address (used only when BIOS_BASE > 0) |
| `STACK_TOP` | *(auto)* | Stack address (auto = MEMTOP; set explicitly if MEM_SIZE doesn't match hardware) |
| `VIDEO_BASE` | `0CC00H` | VDM-1 base address (0 = disabled) |
| `ENABLE_BASIC` | `0` | Include Altair BASIC (0 or 1) |
| `ENABLE_TERM` | `0` | Include terminal mode (0 or 1) |

Video geometry (`VIDEO_COLS`, `VIDEO_ROWS`, `VIDEO_CTRL`) is also configurable. See `config.mk` for the full list.

## Project Structure

```
jx/
├── Makefile            Build rules
├── config.mk           Hardware config (Altair 88-2SIO default)
├── config.mk.sim       Hardware config (cpmsim simulator)
├── config.mk.sio       Hardware config (Altair 88-2SIO alternate)
├── config.mk.rom       Hardware config (ROM-capable, 88-2SIOJP)
├── config.mk.sim.rom   Hardware config (simulator test of config.mk.rom)
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
├── tests/
│   ├── run-tests.sh    Test runner entry point
│   ├── harness.exp     Shared Expect framework
│   └── test-*.exp      Functional tests (boot, dump, write, io, basic)
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
- **[BitsBy8](https://github.com/joezilla/fdcplus-web)** -- Disk server and
  virtual S-100 workbench used to boot-test ROM builds (see [Testing](#testing))

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
