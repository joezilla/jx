# JX Operating System Design Specification

## Version 0.1 - Initial Architecture

This document defines the core design assumptions and memory layout for JX, an operating system for Intel 8080-based computers. It serves as the authoritative reference for all development.

---

## 1. Design Goals

### 1.1 Primary Objectives

- **Scalability**: Support systems with 32KB to 64KB of RAM without recompilation of user programs
- **Simplicity**: Minimal, understandable codebase that can be maintained and extended
- **Compatibility**: Familiar conventions for 8080 programmers; CP/M-inspired but not CP/M-compatible
- **Portability**: Clean BIOS abstraction to support diverse hardware configurations

### 1.2 Non-Goals

- Binary compatibility with CP/M (source-level compatibility may be considered)
- Support for systems with less than 32KB RAM
- Bank switching or memory expansion beyond 64KB (future extension possible)

---

## 2. Hardware Requirements

### 2.1 Minimum Configuration

| Component | Requirement |
|-----------|-------------|
| CPU | Intel 8080A or compatible (8085, Z80 in 8080 mode) |
| RAM | 32KB minimum, contiguous from 0x0000 |
| ROM | Optional; system can boot from disk |
| Storage | At least one block device (floppy, CF card, etc.) |
| Console | Serial terminal or memory-mapped display + keyboard |

### 2.2 Memory Assumptions

- RAM starts at address 0x0000
- RAM is contiguous up to the top of available memory
- No memory-mapped I/O in the range 0x0000 to MEMTOP (I/O uses ports)
- ROM, if present, may be at high addresses or bank-switched out after boot

### 2.3 Interrupt Model

JX uses **polled I/O** by default. Hardware interrupts are optional and handled by the BIOS. The RST vectors are reserved for system use regardless of interrupt configuration.

---

## 3. Memory Layout

### 3.1 Overview

```
                    64KB System          32KB System
                   ┌───────────┐ FFFF
                   │   BIOS    │
                   ├───────────┤ FE00   ┌───────────┐ 7FFF
                   │   BDOS    │        │   BIOS    │
                   ├───────────┤ F600   ├───────────┤ 7E00
                   │   Stack   │        │   BDOS    │
                   ├───────────┤ F500   ├───────────┤ 7600
                   │           │        │   Stack   │
                   │           │        ├───────────┤ 7500
                   │    TPA    │        │           │
                   │           │        │    TPA    │
                   │           │        │           │
                   ├───────────┤ 0100   ├───────────┤ 0100
                   │  Page 0   │        │  Page 0   │
                   └───────────┘ 0000   └───────────┘ 0000
```

### 3.2 Component Sizes

| Component | Size | Notes |
|-----------|------|-------|
| Page Zero | 256 bytes | Fixed at 0x0000-0x00FF |
| TPA | Variable | 0x0100 to STACK_BASE-1 |
| System Stack | 256 bytes | Used by BDOS and system calls |
| BDOS | 2KB (2048 bytes) | Core system services |
| BIOS | 512 bytes | Hardware abstraction layer |

### 3.3 Address Calculation

The system dynamically calculates component addresses based on detected memory:

```
MEMTOP     = Top of RAM + 1 (e.g., 0x8000 for 32KB, 0x10000 for 64KB)
BIOS_BASE  = MEMTOP - 0x0200 (512 bytes)
BDOS_BASE  = BIOS_BASE - 0x0800 (2048 bytes)
STACK_TOP  = BDOS_BASE
STACK_BASE = STACK_TOP - 0x0100 (256 bytes)
TPA_TOP    = STACK_BASE
TPA_BASE   = 0x0100 (fixed)
TPA_SIZE   = TPA_TOP - TPA_BASE
```

### 3.4 Memory Size Examples

| Total RAM | BIOS_BASE | BDOS_BASE | TPA_TOP | TPA Size |
|-----------|-----------|-----------|---------|----------|
| 32KB | 0x7E00 | 0x7600 | 0x7500 | 29,440 bytes |
| 40KB | 0x9E00 | 0x9600 | 0x9500 | 37,632 bytes |
| 48KB | 0xBE00 | 0xB600 | 0xB500 | 45,824 bytes |
| 56KB | 0xDE00 | 0xD600 | 0xD500 | 54,016 bytes |
| 64KB | 0xFE00 | 0xF600 | 0xF500 | 62,208 bytes |

---

## 4. Page Zero (0x0000-0x00FF)

Page Zero contains system entry points, interrupt vectors, and default parameter areas.

### 4.1 Layout

```
Address   Size   Description
-------   ----   -----------
0x0000    3      Warm boot entry: JP BIOS_BOOT
0x0003    1      IOBYTE (I/O configuration byte)
0x0004    1      Current drive (0=A, 1=B, ...)
0x0005    3      BDOS entry: JP BDOS_ENTRY
0x0008    3      RST 1 vector (reserved)
0x0010    3      RST 2 vector (reserved)
0x0018    3      RST 3 vector (reserved)
0x0020    3      RST 4 vector (reserved)
0x0028    3      RST 5 vector (reserved)
0x0030    3      RST 6 vector (reserved)
0x0038    3      RST 7 vector (reserved/interrupts)
0x003B    5      Reserved
0x0040    16     System scratch area
0x0050    12     Reserved for future use
0x005C    36     Default FCB 1 (File Control Block)
0x0080    128    Default DMA buffer / command tail
```

### 4.2 Warm Boot Entry (0x0000)

Programs can perform a warm boot by jumping to address 0x0000. This reloads the CCP (if implemented) but preserves the BDOS and BIOS.

```asm
; Example: Exit program with warm boot
    JP    0x0000
```

### 4.3 BDOS Entry (0x0005)

All system calls go through the BDOS entry point at 0x0005. The function number is passed in register C, with parameters in DE or E as appropriate.

```asm
; Example: Print character 'A'
    MVI   C, 02H      ; Function 2: Console output
    MVI   E, 'A'      ; Character to print
    CALL  0x0005      ; Call BDOS
```

### 4.4 Default FCB (0x005C)

The default FCB is populated by the CCP when a program is loaded. It contains the parsed filename from the first command-line argument.

```
Offset  Size  Field
------  ----  -----
0       1     Drive (0=default, 1=A, 2=B, ...)
1       8     Filename (space-padded)
9       3     Extension (space-padded)
12      1     Extent number
13      2     Reserved
15      1     Record count
16      16    Disk allocation map
32      1     Current record
33      3     Random record number (optional)
```

### 4.5 Command Tail Buffer (0x0080)

The 128-byte buffer at 0x0080 serves dual purposes:
1. **Before program execution**: Contains the command tail (arguments after program name)
2. **During execution**: Default DMA (Direct Memory Access) buffer for disk operations

Format of command tail:
```
0x0080: Length byte (n)
0x0081: Command tail string (n bytes, space-prefixed)
```

---

## 5. System Call Interface

### 5.1 Calling Convention

System calls use the following register conventions:

| Register | Purpose |
|----------|---------|
| C | Function number |
| DE | Parameter (address or value) |
| E | Parameter (single byte) |
| A | Return value (single byte) |
| HL | Return value (address or 16-bit value) |

All other registers may be destroyed by system calls unless otherwise documented.

### 5.2 System Call Table

#### Console Functions (0x00-0x0F)

| Number | Name | Input | Output | Description |
|--------|------|-------|--------|-------------|
| 0x00 | S_RESET | - | - | System reset (warm boot) |
| 0x01 | C_READ | - | A=char | Read console character (wait) |
| 0x02 | C_WRITE | E=char | - | Write character to console |
| 0x03 | R_READ | - | A=char | Read from reader device |
| 0x04 | P_WRITE | E=char | - | Write to punch device |
| 0x05 | L_WRITE | E=char | - | Write to list device (printer) |
| 0x06 | C_RAWIO | E=mode | A=char | Direct console I/O |
| 0x07 | C_GETIOB | - | A=iobyte | Get I/O byte |
| 0x08 | C_SETIOB | E=iobyte | - | Set I/O byte |
| 0x09 | C_WRITESTR | DE=addr | - | Print string (terminated by '$') |
| 0x0A | C_READSTR | DE=addr | - | Read console buffer |
| 0x0B | C_STAT | - | A=status | Get console status (0=no char, FF=ready) |

#### Disk Functions (0x10-0x2F)

| Number | Name | Input | Output | Description |
|--------|------|-------|--------|-------------|
| 0x0D | D_RESET | - | - | Reset disk system |
| 0x0E | D_SELECT | E=drive | - | Select disk (0=A, 1=B, ...) |
| 0x0F | F_OPEN | DE=FCB | A=status | Open file |
| 0x10 | F_CLOSE | DE=FCB | A=status | Close file |
| 0x11 | F_SFIRST | DE=FCB | A=status | Search for first match |
| 0x12 | F_SNEXT | - | A=status | Search for next match |
| 0x13 | F_DELETE | DE=FCB | A=status | Delete file |
| 0x14 | F_READ | DE=FCB | A=status | Read sequential |
| 0x15 | F_WRITE | DE=FCB | A=status | Write sequential |
| 0x16 | F_MAKE | DE=FCB | A=status | Create file |
| 0x17 | F_RENAME | DE=FCB | A=status | Rename file |
| 0x18 | D_LOGIVEC | - | HL=vector | Get login vector |
| 0x19 | D_GETCUR | - | A=drive | Get current drive |
| 0x1A | F_SETDMA | DE=addr | - | Set DMA address |
| 0x1B | D_GETALV | - | HL=addr | Get allocation vector |
| 0x1C | D_WRPROT | - | - | Write protect disk |
| 0x1D | D_GETROV | - | HL=vector | Get read-only vector |
| 0x1E | F_SETATT | DE=FCB | A=status | Set file attributes |
| 0x1F | D_GETDPB | - | HL=addr | Get disk parameter block |
| 0x20 | F_GETUSER | E=code | A=user | Get/set user number |
| 0x21 | F_RREAD | DE=FCB | A=status | Read random |
| 0x22 | F_RWRITE | DE=FCB | A=status | Write random |
| 0x23 | F_SIZE | DE=FCB | - | Compute file size |
| 0x24 | F_SETREC | DE=FCB | - | Set random record |

#### Extended Functions (0x30+)

Reserved for JX-specific extensions.

| Number | Name | Input | Output | Description |
|--------|------|-------|--------|-------------|
| 0x30 | S_GETVER | - | HL=version | Get system version |
| 0x31 | S_GETTPA | - | HL=TPA_TOP | Get TPA top address |
| 0x32 | S_GETMEM | - | HL=MEMTOP | Get total memory |

### 5.3 Return Codes

| Value | Meaning |
|-------|---------|
| 0x00 | Success / found |
| 0x01-0xFE | Function-specific |
| 0xFF | Error / not found |

---

## 6. BIOS Specification

The BIOS (Basic Input/Output System) provides hardware abstraction. Each hardware platform requires a custom BIOS implementation.

### 6.1 BIOS Jump Table

The BIOS begins with a jump table at BIOS_BASE. All entries are 3 bytes (JP instruction).

```
Offset  Vector        Description
------  ------        -----------
+0x00   BIOS_BOOT     Cold boot
+0x03   BIOS_WBOOT    Warm boot
+0x06   BIOS_CONST    Console status
+0x09   BIOS_CONIN    Console input
+0x0C   BIOS_CONOUT   Console output
+0x0F   BIOS_LIST     List output
+0x12   BIOS_PUNCH    Punch output
+0x15   BIOS_READER   Reader input
+0x18   BIOS_HOME     Home disk head
+0x1B   BIOS_SELDSK   Select disk
+0x1E   BIOS_SETTRK   Set track
+0x21   BIOS_SETSEC   Set sector
+0x24   BIOS_SETDMA   Set DMA address
+0x27   BIOS_READ     Read sector
+0x2A   BIOS_WRITE    Write sector
+0x2D   BIOS_LISTST   List device status
+0x30   BIOS_SECTRN   Sector translate
```

### 6.2 BIOS Function Specifications

#### BIOS_BOOT (Cold Boot)
- Initialize hardware
- Detect memory size
- Relocate BDOS if needed
- Initialize Page Zero
- Jump to CCP or command prompt

#### BIOS_WBOOT (Warm Boot)
- Reload CCP (if transient)
- Reinitialize Page Zero jump vectors
- Jump to CCP

#### BIOS_CONST (Console Status)
- **Input**: None
- **Output**: A = 0x00 if no character ready, 0xFF if character ready
- Must be non-blocking

#### BIOS_CONIN (Console Input)
- **Input**: None
- **Output**: A = character read
- Blocks until character available

#### BIOS_CONOUT (Console Output)
- **Input**: C = character to output
- **Output**: None
- Blocks until character sent

#### BIOS_SELDSK (Select Disk)
- **Input**: C = disk number (0=A, 1=B, ...)
- **Output**: HL = address of Disk Parameter Header (DPH), or 0 if invalid

#### BIOS_READ / BIOS_WRITE (Sector I/O)
- **Input**: Disk, track, sector, DMA set by prior calls
- **Output**: A = 0 on success, 1 on error

### 6.3 Disk Parameter Header (DPH)

Each disk has a 16-byte DPH:

```
Offset  Size  Field
------  ----  -----
0       2     XLT - Sector translation table address (0 if none)
2       6     Scratch area (used by BDOS)
8       2     DIRBUF - Directory buffer address
10      2     DPB - Disk Parameter Block address
12      2     CSV - Checksum vector address
14      2     ALV - Allocation vector address
```

### 6.4 Disk Parameter Block (DPB)

```
Offset  Size  Field
------  ----  -----
0       2     SPT - Sectors per track
2       1     BSH - Block shift factor
3       1     BLM - Block mask
4       1     EXM - Extent mask
5       2     DSM - Total blocks - 1
7       2     DRM - Directory entries - 1
9       1     AL0 - Allocation bitmap 0
10      1     AL1 - Allocation bitmap 1
11      2     CKS - Checksum vector size
13      2     OFF - Track offset (reserved tracks)
```

---

## 7. Boot Sequence

### 7.1 Cold Boot Process

1. **Hardware initialization**
   - Initialize CPU (disable interrupts)
   - Initialize stack pointer to temporary location
   - Initialize console device

2. **Memory detection**
   - Probe memory from 0x8000 upward
   - Write/read test pattern to find MEMTOP
   - Store MEMTOP for later use

3. **System loading**
   - Calculate BIOS_BASE, BDOS_BASE from MEMTOP
   - Load or relocate BDOS to BDOS_BASE
   - Initialize BIOS variables

4. **Page Zero initialization**
   - Set JP BIOS_WBOOT at 0x0000
   - Set JP BDOS_ENTRY at 0x0005
   - Clear default FCB and DMA areas

5. **System ready**
   - Initialize disk system
   - Print sign-on message
   - Jump to CCP or command interpreter

### 7.2 Memory Detection Algorithm

```asm
;--------------------------------------------
; MEMPROBE - Detect top of memory
; Output: HL = first invalid address (MEMTOP)
;--------------------------------------------
MEMPROBE:
    LD    HL, 8000H       ; Start at 32KB (minimum)
.LOOP:
    LD    A, H
    CP    00H             ; Wrapped to 0? (past 64KB)
    JR    Z, .DONE

    LD    A, (HL)         ; Read current value
    LD    B, A            ; Save it
    CPL                   ; Complement
    LD    (HL), A         ; Write complement
    CP    (HL)            ; Read back - match?
    LD    (HL), B         ; Restore original
    JR    NZ, .DONE       ; No match = no RAM here

    INC   H               ; Next 256-byte page
    JR    .LOOP

.DONE:
    RET                   ; HL = MEMTOP
```

---

## 8. Transient Program Area (TPA)

### 8.1 Program Loading

Programs are loaded at TPA_BASE (0x0100) and must be position-independent or assembled for that address. The maximum program size is TPA_SIZE.

### 8.2 Program Entry

Programs receive control at 0x0100 with:
- SP set to STACK_TOP
- Default FCB at 0x005C populated with first filename argument
- Command tail at 0x0080 containing remaining arguments
- Default DMA address set to 0x0080

### 8.3 Program Exit

Programs should exit by one of:
1. `JP 0x0000` - Warm boot (standard exit)
2. `RET` - Returns to CCP if SP unchanged (not guaranteed)
3. System call 0x00 (S_RESET)

### 8.4 Memory Usage Rules

- Programs may use 0x0100 to TPA_TOP-1 freely
- Page Zero (0x0000-0x00FF) should not be modified except:
  - Default FCB (0x005C-0x007F) may be used as working FCB
  - DMA buffer (0x0080-0x00FF) may be used freely
- Programs must not access memory at TPA_TOP or above

### 8.5 Determining Available Memory

Programs can determine available memory via system call:

```asm
    MVI   C, 31H          ; S_GETTPA
    CALL  0x0005
    ; HL now contains TPA_TOP
```

---

## 9. File System

### 9.1 Overview

JX uses a simple block-based file system inspired by CP/M. Details to be specified in a separate document.

### 9.2 Key Characteristics

- 8.3 filename format (8 character name, 3 character extension)
- Single-level directory per disk
- Block-based allocation
- User numbers (0-15) for file organization

---

## 10. Implementation Notes

### 10.1 BDOS Implementation

The BDOS should be:
- Position-independent OR assembled with a link-time base address
- Self-contained (no external dependencies except BIOS calls)
- Re-entrant where possible (for future interrupt support)

### 10.2 Relocation Strategy

Two approaches are supported:

**Approach A: Multiple BDOS binaries**
- Assemble BDOS for each supported memory size
- Boot loader selects correct binary based on detected RAM

**Approach B: Runtime relocation**
- BDOS assembled for base address 0x0000
- Boot loader applies relocation fixups based on MEMTOP
- Requires relocation table appended to BDOS binary

Approach A is recommended for simplicity.

### 10.3 Source Code Organization

```
jx/
├── DESIGN.md           # This document
├── bios/
│   ├── bios.asm        # BIOS template
│   └── hw/             # Hardware-specific implementations
├── bdos/
│   ├── bdos.asm        # BDOS core
│   ├── console.asm     # Console functions
│   ├── disk.asm        # Disk functions
│   └── file.asm        # File operations
├── ccp/
│   └── ccp.asm         # Console Command Processor
├── tools/
│   └── ...             # Build tools, utilities
└── doc/
    └── ...             # Additional documentation
```

---

## 11. Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-01-22 | Initial architecture specification |

---

## 12. References

- Intel 8080 Microcomputer Systems User's Manual
- CP/M 2.2 Operating System Manual (for conceptual reference)
- S-100 Bus architecture documentation

---

## Appendix A: Quick Reference

### Memory Map Summary

| Region | Start | Size | Purpose |
|--------|-------|------|---------|
| Page Zero | 0x0000 | 256 | System vectors, FCB, DMA |
| TPA | 0x0100 | Variable | User programs |
| Stack | TPA_TOP | 256 | System stack |
| BDOS | BDOS_BASE | 2048 | System services |
| BIOS | BIOS_BASE | 512 | Hardware abstraction |

### Key Addresses

| Symbol | 32KB | 64KB | Description |
|--------|------|------|-------------|
| MEMTOP | 0x8000 | 0x10000* | Top of RAM (+1) |
| BIOS_BASE | 0x7E00 | 0xFE00 | BIOS start |
| BDOS_BASE | 0x7600 | 0xF600 | BDOS start |
| TPA_TOP | 0x7500 | 0xF500 | TPA end (+1) |
| TPA_BASE | 0x0100 | 0x0100 | TPA start |

*Note: 0x10000 wraps to 0x0000 in 16-bit arithmetic; use 0xFFFF+1 conceptually.

### Essential System Calls

| Function | C | Input | Output | Description |
|----------|---|-------|--------|-------------|
| Console out | 02 | E=char | - | Print character |
| Print string | 09 | DE=addr | - | Print '$'-terminated string |
| Console in | 01 | - | A=char | Read character |
| Open file | 0F | DE=FCB | A=status | Open for read/write |
| Read seq | 14 | DE=FCB | A=status | Read 128 bytes |
| Write seq | 15 | DE=FCB | A=status | Write 128 bytes |
| Warm boot | 00 | - | - | Exit program |
