# JX Operating System

A CP/M-like operating system for Intel 8080, featuring C programming support via SDCC compiler.

## Features

- Intel 8080 CPU architecture
- CP/M-compatible BIOS and BDOS
- Interactive console command processor (CCP)
- Full C programming environment with SDCC
- Comprehensive C library (stdio, string, stdlib, malloc)
- 32KB, 48KB, or 64KB memory configurations
- Compatible with z80pack simulator

## Quick Start

### Prerequisites

- **z80pack** (z80asm assembler and cpmsim simulator)
- **SDCC** 4.5.0 or later (for C programming)
- **GNU Make**

**macOS:**
```bash
brew install sdcc
# Clone and build z80pack from https://github.com/udo-munk/z80pack
```

**Linux:**
```bash
sudo apt-get install sdcc build-essential
# Clone and build z80pack
```

### Building

```bash
# Clone repository
git clone <repository-url>
cd jx

# Configure paths (edit if needed)
vi config.mk

# Build complete system
make all

# Run in simulator
make run
```

## System Architecture

### Memory Layout (64KB Configuration)

```
0x0000 - 0x00FF    Page Zero (system vectors)
0x0100 - 0xF4FF    TPA (Transient Program Area) - 62KB
0xF500 - 0xFCFF    BDOS (Basic Disk Operating System)
0xFD00 - 0xFFFF    BIOS (Basic Input/Output System)
```

### Components

**BIOS** (`src/bios/bios.asm`)
- Hardware abstraction layer
- Console I/O
- Cold/warm boot
- CCP backup/restore

**BDOS** (`src/bdos/bdos.asm`)
- System call interface
- Console I/O functions
- Memory management
- Future: File I/O

**CCP** (`src/ccp/ccp.c`)
- Interactive command shell
- Built-in commands (help, ver, mem, cls, exit)
- Command parsing
- Future: External program loading

**C Library** (`src/clib/`)
- Standard I/O (printf, puts, gets, putchar, getchar)
- String functions (strlen, strcpy, strcmp, memcpy, etc.)
- Memory allocation (malloc, calloc, realloc, free)
- BDOS interface (bdos() wrapper functions)

## Programming in C

### Hello World

```c
#include <stdio.h>

int main(void) {
    printf("Hello from JX!\n");
    return 0;
}
```

**Build and run:**
```bash
# Save as src/examples/hello.c
make build/examples/hello.hex
make run-example EXAMPLE=hello
```

### Available Libraries

**stdio.h**
- `printf()`, `puts()`, `putchar()`, `getchar()`, `gets()`

**string.h**
- `strlen()`, `strcpy()`, `strcmp()`, `strcat()`
- `memcpy()`, `memset()`, `memcmp()`, `memmove()`
- `strchr()`, `strrchr()`, `strtok()`

**stdlib.h**
- `malloc()`, `calloc()`, `realloc()`, `free()`
- `atoi()`, `itoa()`, `utoa()`
- `heap_used()`, `heap_available()` (JX extensions)

**bdos.h**
- `bdos()` - Direct BDOS system calls
- `bdos_conin()`, `bdos_conout()`, `bdos_print()`
- `bdos_gettpa()`, `bdos_getmem()`

### Example Programs

**Memory allocation:**
```c
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    char *buf = malloc(256);
    if (!buf) {
        printf("Out of memory!\n");
        return 1;
    }

    strcpy(buf, "Dynamic memory works!");
    printf("%s\n", buf);
    printf("Heap used: %u bytes\n", heap_used());

    return 0;
}
```

**String processing:**
```c
#include <stdio.h>
#include <string.h>

int main(void) {
    char line[128];
    char *token;

    printf("Enter words: ");
    gets(line);

    token = strtok(line, " ");
    while (token) {
        printf("Word: %s\n", token);
        token = strtok(NULL, " ");
    }

    return 0;
}
```

See `docs/PROGRAMMING_C.md` for comprehensive C programming guide.

## Console Command Processor (CCP)

The CCP is an interactive shell that starts automatically on boot.

### Built-in Commands

| Command | Description |
|---------|-------------|
| `help` or `?` | Show available commands |
| `ver` or `version` | Show system version |
| `mem` or `memory` | Show memory information |
| `cls` or `clear` | Clear screen |
| `exit` or `quit` | Exit to system (warm boot) |

### Example Session

```
========================================
  JX Operating System
  Console Command Processor v1.0
========================================

Type 'help' for available commands

JX> ver
JX Operating System
  CCP Version:  1.0
  BDOS Version: 2.2
  Architecture: Intel 8080
  Compiler:     SDCC 4.x

JX> mem
Memory Layout:
  Total Memory:  64 KB

  TPA:   0x0100 - 0xF400  (62208 bytes, 60 KB)
  BDOS:  0xF500 - 0xFCFF
  BIOS:  0xFD00 - 0xFFFF

Heap Status:
  Used:      0 bytes
  Available: 61952 bytes

JX> _
```

See `docs/CCP_GUIDE.md` for detailed CCP documentation.

## Build System

### Build Targets

```bash
make all          # Build complete system
make bios         # Build BIOS only
make bdos         # Build BDOS only
make ccp          # Build CCP only
make examples     # Build C library and examples
make test         # Build test programs
make clean        # Remove build artifacts
make distclean    # Remove build directory
make help         # Show help message
```

### Building C Programs

```bash
# Build C library
make build/libjx.lib

# Build your program
make build/examples/yourprogram.hex

# Run in simulator
make run-example EXAMPLE=yourprogram
```

### Memory Configurations

```bash
# Build for 32KB system
make MEM_SIZE=32 all

# Build for 48KB system
make MEM_SIZE=48 all

# Build for 64KB system (default)
make MEM_SIZE=64 all
```

See `docs/BUILD_SYSTEM.md` for complete build documentation.

## Project Structure

```
jx/
├── Makefile                Main build file
├── config.mk               Toolchain configuration
├── src/
│   ├── bios/
│   │   └── bios.asm       BIOS assembly source
│   ├── bdos/
│   │   └── bdos.asm       BDOS assembly source
│   ├── ccp/
│   │   └── ccp.c          CCP C source
│   ├── clib/              C library source
│   │   ├── crt0/
│   │   │   └── crt0.s     C runtime startup
│   │   ├── bdos/
│   │   │   ├── bdos.h
│   │   │   └── bdos.c     BDOS interface
│   │   ├── stdio/
│   │   │   ├── stdio.h
│   │   │   ├── printf.c
│   │   │   ├── puts.c
│   │   │   └── ...
│   │   ├── string/
│   │   │   ├── string.h
│   │   │   ├── strlen.c
│   │   │   └── ...
│   │   └── stdlib/
│   │       ├── stdlib.h
│   │       ├── malloc.c
│   │       └── ...
│   ├── examples/          Example C programs
│   └── test/              Test programs
├── build/                 Build output (generated)
└── docs/                  Documentation
    ├── PROGRAMMING_C.md   C programming guide
    ├── C_LIBRARY.md       Library reference
    ├── CCP_GUIDE.md       CCP documentation
    ├── BUILD_SYSTEM.md    Build system guide
    ├── TOOLCHAIN.md       Toolchain reference
    └── Z80ASM_BUGS.md     Known z80asm issues
```

## Documentation

- **[C Programming Guide](docs/PROGRAMMING_C.md)** - How to write C programs for JX
- **[C Library Reference](docs/C_LIBRARY.md)** - Complete library documentation
- **[CCP Guide](docs/CCP_GUIDE.md)** - Console Command Processor usage
- **[Build System](docs/BUILD_SYSTEM.md)** - Build system documentation
- **[Toolchain Guide](docs/TOOLCHAIN.md)** - Assembler and compiler reference
- **[z80asm Bugs](docs/Z80ASM_BUGS.md)** - Known issues with z80asm 2.1

## Technical Details

### C Compilation

- **Compiler**: SDCC 4.5.0+ (Z80/8080 target)
- **Standard**: C11
- **Optimization**: Code size (`--opt-code-size`)
- **Memory Model**: Small (code at 0x0100, data at 0x8000)
- **Runtime**: Custom crt0.s for TPA environment

### Memory Management

- **Allocator**: Simple bump allocator
- **malloc()**: Allocates from heap (grows upward)
- **free()**: No-op (memory reclaimed on program exit)
- **Stack**: 256 bytes (grows downward from TPA top)
- **Safety**: 256-byte margin between heap and stack

### Assembly

- **Assembler**: z80asm from z80pack
- **CPU Mode**: 8080 (no Z80 instructions)
- **Output**: Raw binary (.bin) and Intel HEX (.hex)

### Simulator

- **Simulator**: cpmsim from z80pack
- **Flags**: `-8` (8080 mode), `-m 00` (zero memory), `-x` (load HEX)
- **Console I/O**: Fully functional
- **Disk I/O**: Future support

## Development Status

### Completed Features

- ✅ Intel 8080 BIOS implementation
- ✅ BDOS stub with console I/O
- ✅ Interactive CCP shell
- ✅ Full SDCC C compiler integration
- ✅ Comprehensive C library (stdio, string, stdlib)
- ✅ Memory allocation (malloc/calloc/realloc)
- ✅ Cold/warm boot support
- ✅ CCP auto-start on boot
- ✅ Command parsing and execution
- ✅ Memory information commands
- ✅ Extensive documentation

### In Progress

- 🚧 BDOS assembly fixes (z80asm compatibility)
- 🚧 External program loading (requires disk I/O)

### Planned Features

- ⏳ BDOS file I/O functions
- ⏳ Disk drive support
- ⏳ External program loading (.com files)
- ⏳ Command history and line editing
- ⏳ Additional built-in commands
- ⏳ Tab completion

## Known Issues

### z80asm 2.1 Bugs

The z80asm assembler (version 2.1) has several bugs that prevent BDOS from assembling:

- Symbols starting with `BIOS_` trigger "multiple defined symbol" errors
- Symbols starting with `BJMP_` also trigger errors
- Labels starting with `F_` followed by underscores trigger errors
- Inline comments on EQU statements exacerbate issues

**Workarounds:**
1. Use different symbol naming conventions
2. Upgrade to newer z80asm version
3. Use alternative assembler (e.g., sdasz80 from SDCC)

See `docs/Z80ASM_BUGS.md` for detailed bug documentation and test cases.

## Contributing

Contributions are welcome! Areas for contribution:

- BDOS file I/O implementation
- Additional C library functions (math, etc.)
- CCP enhancements (history, completion)
- Bug fixes and optimizations
- Documentation improvements

## License

[Specify license here]

## Credits

- **z80pack**: Udo Munk (https://github.com/udo-munk/z80pack)
- **SDCC**: Small Device C Compiler (https://sdcc.sourceforge.net/)
- **Intel 8080**: Classic 8-bit microprocessor architecture
- **CP/M**: Digital Research, Inc. (design inspiration)

## Contact

[Specify contact information]

---

*JX Operating System - Intel 8080 with C Programming Support*
