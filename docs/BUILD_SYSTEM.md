# JX Operating System - Build System Guide

Complete guide to building the JX Operating System, including assembly components, C programs, and system images.

## Table of Contents

- [Overview](#overview)
- [Configuration](#configuration)
- [Build Targets](#build-targets)
- [Assembly Build Process](#assembly-build-process)
- [C Build Process](#c-build-process)
- [System Image](#system-image)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

---

## Overview

The JX build system uses **GNU Make** with two separate toolchains:
- **z80pack (z80asm)** for assembly language components
- **SDCC** for C language programs

### Build System Files

- `Makefile` - Main build file
- `config.mk` - Toolchain configuration and paths
- `src/` - Source code directory
- `build/` - Output directory (generated)

---

## Configuration

### config.mk

All toolchain paths and settings are in `config.mk`:

```makefile
# z80pack paths
Z80PACK_DIR = ../z80pack
Z80ASM = $(Z80PACK_DIR)/z80asm/z80asm
SIMULATOR = $(Z80PACK_DIR)/cpmsim/cpmsim

# SDCC configuration
SDCC = sdcc
SDCC_FLAGS = -mz80 --std-c11 --opt-code-size --fverbose-asm

# Memory configuration
MEM_SIZE = 64  # 32, 48, or 64 KB
```

### Memory Configurations

The build system supports three memory sizes:

**32 KB:**
```
TPA:  0x0100 - 0x7400  (29 KB)
BDOS: 0x7500 - 0x7CFF
BIOS: 0x7D00 - 0x7FFF
```

**48 KB:**
```
TPA:  0x0100 - 0xB400  (45 KB)
BDOS: 0xB500 - 0xBCFF
BIOS: 0xBD00 - 0xBFFF
```

**64 KB (default):**
```
TPA:  0x0100 - 0xF400  (62 KB)
BDOS: 0xF500 - 0xFCFF
BIOS: 0xFD00 - 0xFFFF
```

**To change memory size:**
```bash
# Edit config.mk and change:
MEM_SIZE = 48

# Or override on command line:
make MEM_SIZE=32 all
```

---

## Build Targets

### Primary Targets

```bash
make all            # Build complete system (default)
make clean          # Remove build artifacts
make distclean      # Remove entire build directory
make help           # Show help message
make info           # Show configuration
```

### Component Targets

```bash
make bios           # Build BIOS only
make bdos           # Build BDOS only
make ccp            # Build CCP (Console Command Processor)
make examples       # Build C library and examples
```

### Test Targets

```bash
make test           # Build all test programs
make test-hello     # Build specific test
make run-test TEST=hello  # Build and run test
```

### Execution Targets

```bash
make run            # Run complete system in simulator
make run-example EXAMPLE=hello  # Run C example program
```

---

## Assembly Build Process

### Directory Structure

```
src/
├── bios/
│   └── bios.asm        → build/bios.bin
├── bdos/
│   └── bdos.asm        → build/bdos.bin
└── test/
    ├── hello.asm       → build/test/hello.hex
    └── boot.asm        → build/test/boot.hex
```

### Assembly Build Steps

1. **Source File** (.asm)
2. **Assemble** with z80asm
3. **Output Formats**:
   - `.bin` - Raw binary (for ROM/system image)
   - `.hex` - Intel HEX (for simulator)
   - `.lis` - Listing file (with addresses)

**Example Build Command:**
```bash
z80asm -8 -fb -l -T -sn -p0 \
       -dBIOS_BASE=0xFD00 \
       -dBDOS_BASE=0xF500 \
       -o build/bios.bin \
       src/bios/bios.asm
```

**Flags:**
- `-8` - 8080 mode (reject Z80 instructions)
- `-fb` - Flat binary output
- `-l` - Generate listing file
- `-T` - Omit symbol table from listing
- `-sn` - Sort symbols numerically
- `-p0` - Fill unused with 0x00

### Memory Defines

The build system passes memory layout via `-d` flags:

```makefile
MEM_DEFINES = -dMEMTOP=$(MEMTOP) \
              -dBIOS_BASE=$(BIOS_BASE) \
              -dBDOS_BASE=$(BDOS_BASE) \
              -dTPA_TOP=$(TPA_TOP)
```

These are calculated based on `MEM_SIZE` setting.

---

## C Build Process

### Directory Structure

```
src/
├── clib/                   C library source
│   ├── crt0/
│   │   └── crt0.s         → build/clib/crt0.rel
│   ├── bdos/
│   │   └── bdos.c         → build/clib/bdos.rel
│   ├── stdio/
│   │   └── printf.c       → build/clib/stdio/printf.rel
│   └── ...
└── examples/
    └── hello.c            → build/examples/hello.hex
```

### C Build Steps

1. **Compile C to Object** (.c → .rel)
   ```bash
   sdcc -mz80 --std-c11 --opt-code-size -c -o file.rel file.c
   ```

2. **Assemble crt0** (.s → .rel)
   ```bash
   sdasz80 -plosgff -o crt0.rel crt0.s
   ```

3. **Create Library** (.rel → .lib)
   ```bash
   sdar -rc libjx.lib file1.rel file2.rel ...
   ```

4. **Link Program** (.rel + .lib → .ihx)
   ```bash
   sdcc -mz80 --code-loc 0x0100 --data-loc 0x8000 \
        --no-std-crt0 -o program.ihx \
        crt0.rel program.rel libjx.lib
   ```

5. **Convert Formats**
   - `.ihx` → `.hex` (Intel HEX): `cp program.ihx program.hex`
   - `.ihx` → `.bin` (raw binary): `makebin -p program.ihx program.bin`

### C Library Build

The C library (`libjx.lib`) is built from multiple components:

```makefile
CLIB_OBJS = build/clib/bdos/bdos.rel \
            build/clib/stdio/putchar.rel \
            build/clib/stdio/printf.rel \
            build/clib/string/strlen.rel \
            build/clib/stdlib/malloc.rel \
            ...

$(LIBJX): $(CLIB_OBJS)
    sdar -rc $@ $(CLIB_OBJS)
```

### C Program Build

**Manual Build:**
```bash
# 1. Build C library
make build/libjx.lib

# 2. Build your program
make build/examples/yourprogram.hex
```

**Makefile Rule:**
```makefile
$(BUILD_DIR)/examples/%.ihx: $(BUILD_DIR)/examples/%.rel \
                              $(CRT0_REL) $(LIBJX)
    $(SDCC) $(SDCC_FLAGS) \
        --code-loc 0x0100 \
        --data-loc 0x8000 \
        --no-std-crt0 \
        -o $@ \
        $(CRT0_REL) $< $(LIBJX)
```

---

## System Image

### System Image Composition

The complete system image combines three components:

```
jx.bin = ccp.bin + bdos.bin + bios.bin
```

**Build Command:**
```bash
cat build/ccp/ccp.bin \
    build/bdos.bin \
    build/bios.bin \
    > build/jx.bin
```

### Memory Layout in Image

```
Offset    Component    Load Address    Size
------    ---------    ------------    ----
0x0000    CCP          0x0100          ~8KB
0x2000    BDOS         0xF500          2KB
0x2800    BIOS         0xFD00          768B
```

**Note**: The CCP is loaded at 0x0100 and backed up to 0xE000 by BIOS during cold boot.

### System Image Build Process

1. **Build CCP** (C program)
   ```bash
   make build/ccp/ccp.bin
   ```

2. **Build BDOS** (assembly)
   ```bash
   make build/bdos.bin
   ```

3. **Build BIOS** (assembly)
   ```bash
   make build/bios.bin
   ```

4. **Concatenate**
   ```bash
   cat build/ccp/ccp.bin build/bdos.bin build/bios.bin > build/jx.bin
   ```

---

## Examples

### Build Everything

```bash
# Clean build from scratch
make distclean
make all

# Output:
#   build/jx.bin          - Complete system
#   build/ccp/ccp.hex     - CCP
#   build/bdos.bin        - BDOS
#   build/bios.bin        - BIOS
```

### Build C Program

```bash
# Create source file
cat > src/examples/demo.c << 'EOF'
#include <stdio.h>
int main(void) {
    printf("Hello from JX!\n");
    return 0;
}
EOF

# Build
make build/examples/demo.hex

# Run in simulator
make run-example EXAMPLE=demo
```

### Build Test Program

```bash
# Assembly test
make build/test/hello.hex

# Run test
make run-test TEST=hello
```

### Build for Different Memory Size

```bash
# Build for 32KB system
make clean
make MEM_SIZE=32 all

# Check configuration
make info
```

---

## Build Workflow

### Full Development Cycle

```bash
# 1. Initial setup
git clone <repository>
cd jx

# 2. Configure toolchain paths
vi config.mk      # Edit Z80PACK_DIR if needed

# 3. Verify tools
make check-tools

# 4. Build everything
make all

# 5. Test in simulator
make run

# 6. Make changes to code
vi src/bios/bios.asm

# 7. Rebuild changed component
make bios

# 8. Rebuild system
make all

# 9. Test again
make run
```

### Incremental Builds

The Makefile uses dependencies to rebuild only what's necessary:

```bash
# Edit C library source
vi src/clib/stdio/printf.c

# Rebuild only affected components
make              # Automatically rebuilds:
                  #   - printf.rel
                  #   - libjx.lib
                  #   - ccp (uses libjx.lib)
                  #   - jx.bin (uses ccp)
```

---

## Troubleshooting

### Build Errors

**Error: z80asm not found**
```bash
# Solution: Check Z80PACK_DIR in config.mk
which ../z80pack/z80asm/z80asm
# If not found, clone and build z80pack
```

**Error: sdcc not found**
```bash
# Solution: Install SDCC
brew install sdcc          # macOS
sudo apt install sdcc      # Linux
```

**Error: undefined reference to '_printf'**
```bash
# Solution: Library not linked
# Make sure libjx.lib is built:
make build/libjx.lib
```

**Error: multiple defined symbol (z80asm)**
```bash
# This is a z80asm 2.1 bug
# See docs/Z80ASM_BUGS.md for details
# Workaround: Rename conflicting symbols
```

### Clean Build Issues

**Stale build artifacts:**
```bash
make distclean    # Remove all build files
make all          # Fresh build
```

**Listing files in src/ directory:**
```bash
find src -name "*.lis" -delete
make all
```

### Memory Configuration Issues

**Program too large for TPA:**
```bash
# Check program size
ls -lh build/examples/program.bin

# If too large, either:
# 1. Optimize code (use --opt-code-size)
# 2. Increase MEM_SIZE
# 3. Reduce program complexity
```

**Link errors about addresses:**
```bash
# Verify memory defines are correct
make info
# Check that TPA_TOP is sufficient
```

---

## Advanced Topics

### Custom Build Rules

**Add new C source directory:**
```makefile
# In Makefile
CLIB_C_SRCS = $(wildcard $(CLIB_DIR)/bdos/*.c) \
              $(wildcard $(CLIB_DIR)/stdio/*.c) \
              $(wildcard $(CLIB_DIR)/mymodule/*.c)  # Add this
```

**Add new assembly source:**
```makefile
# Build custom assembly file
$(BUILD_DIR)/mycode.bin: src/mycode/mycode.asm
    @echo "ASM  $<"
    @$(Z80ASM) $(ASM_FLAGS_BIN) $(MEM_DEFINES) -o$@ $<
```

### Parallel Builds

```bash
# Use make -j for parallel compilation
make -j4 all      # Build with 4 parallel jobs
```

**Note**: The Makefile is designed for parallel builds - independent targets can build simultaneously.

### Cross-Compilation

The toolchain supports cross-compilation from any host platform:
- **macOS** → 8080 binary
- **Linux** → 8080 binary
- **Windows** (via WSL/MinGW) → 8080 binary

No changes needed - binaries are platform-independent.

---

## Build Output Reference

### File Extensions

| Extension | Format | Tool | Purpose |
|-----------|--------|------|---------|
| `.asm` | Assembly source | z80asm | Human-readable source |
| `.bin` | Raw binary | z80asm, makebin | ROM/system image |
| `.hex` | Intel HEX | z80asm, sdcc | Simulator input |
| `.lis` | Listing | z80asm | Debug, addresses |
| `.c` | C source | sdcc | Human-readable source |
| `.rel` | Object code | sdcc, sdasz80 | Intermediate |
| `.lib` | Library archive | sdar | Collection of .rel |
| `.ihx` | Intel HEX | sdcc | Linker output |
| `.map` | Memory map | sdldz80 | Debugging |
| `.sym` | Symbol table | sdldz80 | Debugging |

### Build Directory Structure

```
build/
├── jx.bin                  System image
├── bios.bin                BIOS binary
├── bdos.bin                BDOS binary
├── libjx.lib               C library
├── ccp/
│   ├── ccp.hex             CCP Intel HEX
│   └── ccp.bin             CCP binary
├── clib/
│   ├── crt0.rel            C runtime
│   ├── bdos/
│   │   └── bdos.rel
│   ├── stdio/
│   │   ├── printf.rel
│   │   └── ...
│   └── ...
├── examples/
│   ├── hello.hex
│   ├── hello.bin
│   └── ...
└── test/
    ├── hello.hex
    └── ...
```

---

## Performance

### Build Times

Typical build times on modern hardware:

| Target | Time | Notes |
|--------|------|-------|
| `make bios` | <1s | Single assembly file |
| `make bdos` | <1s | Single assembly file |
| `make ccp` | 2-3s | C compilation + linking |
| `make examples` | 5-10s | Multiple C files |
| `make all` | 5-10s | Complete system |
| `make clean` | <1s | Remove artifacts |

### Optimization

**Faster builds:**
- Use `make -j` for parallel builds
- Build only changed components
- Use `make component` instead of `make all`

**Smaller binaries:**
- Use `--opt-code-size` (default)
- Minimize printf usage (use puts)
- Avoid large static arrays

---

## See Also

- **Toolchain Guide**: `TOOLCHAIN.md`
- **C Programming**: `PROGRAMMING_C.md`
- **C Library Reference**: `C_LIBRARY.md`
- **CCP Guide**: `CCP_GUIDE.md`

---

*Last Updated: 2026-01-29*
*JX Operating System - Build System Guide*
