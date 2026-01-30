# JX Console Command Processor (CCP) Guide

Complete guide to the JX Operating System interactive shell.

## Table of Contents

- [Overview](#overview)
- [Starting the CCP](#starting-the-ccp)
- [Command Line Editing](#command-line-editing)
- [Built-in Commands](#built-in-commands)
- [Running Programs](#running-programs)
- [Architecture](#architecture)
- [Customization](#customization)

---

## Overview

The **Console Command Processor (CCP)** is the interactive shell for the JX Operating System. It provides a command-line interface for running programs and managing the system.

### Features

- ✅ Interactive command prompt
- ✅ Line editing with backspace support
- ✅ Built-in commands
- ✅ Command parsing and tokenization
- ✅ Memory and system information
- ✅ Auto-start on boot
- ✅ Warm boot support
- 🚧 External program loading (future)

### Specifications

- **Size:** ~7.7 KB compiled
- **Load Address:** 0x0100 (TPA_BASE)
- **Language:** C (compiled with SDCC)
- **Source:** `src/ccp/ccp.c`

---

## Starting the CCP

### Automatic Start (Cold Boot)

The CCP automatically starts when JX boots:

1. BIOS performs hardware initialization
2. BIOS backs up CCP to high memory (0xE000)
3. BIOS jumps to CCP at 0x0100
4. CCP displays banner and prompt

**Boot Sequence:**
```
========================================
  JX Operating System
  Console Command Processor v1.0
========================================

Type 'help' for available commands

JX> _
```

### Manual Start (Warm Boot)

After a program exits, the system performs a warm boot:

1. Control returns to BDOS (function 0x00)
2. BDOS jumps to warm boot vector at 0x0000
3. BIOS reloads CCP from backup (0xE000 → 0x0100)
4. BIOS jumps to CCP at 0x0100
5. CCP displays clean prompt

**Warm Boot Behavior:**
- CCP is restored from backup
- Page Zero vectors are reinitialized
- System state is reset
- Prompt appears with newline

---

## Command Line Editing

### Input Features

**Line Editing:**
- Type characters to build command line
- Characters are echoed as typed
- Maximum line length: 127 characters

**Backspace/Delete:**
- Press `Backspace` or `Delete` to remove last character
- Visual feedback: `<BS><SPACE><BS>`
- Cannot backspace past beginning of line

**Line Completion:**
- Press `Enter` or `Return` to submit command
- Empty lines are ignored (prompt reappears)

### Input Behavior

**Example Session:**
```
JX> helo<BS><BS><BS><BS>help
```

User types: `h` `e` `l` `o` `<BS>` `<BS>` `<BS>` `<BS>` `h` `e` `l` `p`

Result: Command "help" is executed

---

## Built-in Commands

### help (or ?)

**Description:** Display available commands

**Usage:**
```
help
?
```

**Output:**
```
Available commands:
  help, ?       Show this help message
  ver, version  Show system version
  mem, memory   Show memory information
  cls, clear    Clear screen
  exit, quit    Exit to system

Built-in commands are case-sensitive.
```

**Notes:**
- Commands are case-sensitive
- Both long and short forms shown
- No arguments required

---

### ver (or version)

**Description:** Show system version information

**Usage:**
```
ver
version
```

**Output:**
```
JX Operating System
  CCP Version:  1.0
  BDOS Version: 2.2
  Architecture: Intel 8080
  Compiler:     SDCC 4.x
```

**Information Shown:**
- CCP version number
- BDOS version (from BDOS function 0x0C)
- Target CPU architecture
- Compiler used to build

---

### mem (or memory)

**Description:** Display memory layout and usage

**Usage:**
```
mem
memory
```

**Output:**
```
Memory Layout:
  Total Memory:  64 KB

  TPA:   0x0100 - 0xF400  (62208 bytes, 60 KB)
  BDOS:  0xF500 - 0xFCFF
  BIOS:  0xFD00 - 0xFFFF

Heap Status:
  Used:      0 bytes
  Available: 61952 bytes
```

**Information Shown:**

**Memory Layout:**
- Total system memory (from BDOS)
- TPA range and size
- BDOS location
- BIOS location

**Heap Status:**
- Bytes currently allocated
- Bytes still available for allocation

**Notes:**
- Values are dynamic based on actual allocations
- TPA range depends on memory configuration
- Heap statistics from stdlib functions

---

### cls (or clear)

**Description:** Clear screen

**Usage:**
```
cls
clear
```

**Behavior:**
- Sends ANSI escape sequence: `\033[2J\033[H`
- Clears screen (if terminal supports ANSI)
- Moves cursor to home position (0,0)
- Prompt reappears at top of screen

**Notes:**
- Requires ANSI-compatible terminal
- cpmsim simulator supports ANSI escapes
- No effect on non-ANSI terminals

---

### exit (or quit)

**Description:** Exit CCP and return to system

**Usage:**
```
exit
quit
```

**Behavior:**
1. Prints: `Exiting JX...`
2. Calls BDOS function 0x00 (warm boot)
3. System reloads CCP and restarts
4. Equivalent to warm boot

**Notes:**
- Currently causes system restart
- CCP is reloaded from backup
- All program state is lost
- Future: might power down or halt

---

## Running Programs

### External Programs (Future)

**Usage:**
```
programname [arguments]
```

**Behavior (when implemented):**
1. CCP parses command line
2. CCP searches for `programname.com` on disk
3. CCP loads program to 0x0100 (overwrites CCP)
4. CCP sets up arguments at 0x0080
5. CCP jumps to 0x0100
6. Program runs
7. Program exits via BDOS function 0x00
8. System warm boots and reloads CCP

**Current Status:**
- External program loading not yet implemented
- Requires BDOS disk I/O functions
- Stub function returns "Unknown command"

**Example (future):**
```
JX> hello
Hello from JX!

JX> demo
[demo program output]

JX> _
```

---

## Architecture

### CCP Lifecycle

#### Cold Boot (System Start)

```
Power On
   ↓
BIOS Cold Boot (0xFE00)
   ↓
Initialize Hardware
   ↓
Detect Memory
   ↓
Initialize Page Zero
   ↓
Backup CCP: 0x0100 → 0xE000
   ↓
Jump to CCP (0x0100)
   ↓
CCP Main Loop
```

#### Warm Boot (Program Exit)

```
Program calls BDOS function 0x00
   ↓
BDOS jumps to 0x0000 (Warm Boot Vector)
   ↓
BIOS Warm Boot (0xFE00+3)
   ↓
Reinitialize Page Zero
   ↓
Reload CCP: 0xE000 → 0x0100
   ↓
Jump to CCP (0x0100)
   ↓
CCP Main Loop
```

### Memory Layout

**CCP Location:**
```
0x0100 - 0x0E00   CCP code and data (~3.4 KB)
0xE000 - 0xEE00   CCP backup (for warm boot)
```

**When Program Runs:**
```
0x0100 - 0xF4FF   Program overwrites CCP
                  (CCP backed up at 0xE000)
```

**After Program Exits:**
```
0x0100 - 0x0E00   CCP restored from backup
```

### Command Processing

**Main Loop:**
```c
while (1) {
    printf(PROMPT);           // Display "JX> "
    gets(cmdline);            // Read input (with backspace)

    cmd = strtok(cmdline, " "); // Parse command
    arg = strtok(NULL, "");     // Get arguments

    if (builtin_command(cmd)) {
        execute_builtin(cmd, arg);
    } else {
        load_program(cmd, arg); // Future: load from disk
    }
}
```

**Command Parsing:**
1. Tokenize on space/tab
2. First token = command
3. Remaining tokens = arguments
4. Case-sensitive comparison

### Built-in vs External

**Built-in Commands:**
- Part of CCP binary
- Always available
- Fast execution
- Limited functionality
- Current: help, ver, mem, cls, exit

**External Programs:**
- Loaded from disk (future)
- Executable .com files
- Unlimited functionality
- Overwrite CCP in TPA
- Restored on exit

---

## Customization

### Adding Built-in Commands

**Location:** `src/ccp/ccp.c`

**Steps:**

1. **Add function declaration:**
```c
void cmd_mycommand(void);
```

2. **Add command handler:**
```c
void cmd_mycommand(void) {
    printf("My custom command!\n");
    // Your implementation here
}
```

3. **Add to command parser:**
```c
} else if (strcmp(cmd, "mycommand") == 0) {
    cmd_mycommand();
```

4. **Update help text:**
```c
void cmd_help(void) {
    printf("Available commands:\n");
    printf("  mycommand     My custom command\n");
    // ...
}
```

5. **Rebuild:**
```bash
make ccp
```

### Changing Prompt

**Location:** `src/ccp/ccp.c`

**Current:**
```c
#define PROMPT "JX> "
```

**Modify to:**
```c
#define PROMPT "$ "        // Unix-style
#define PROMPT "> "        // Simple
#define PROMPT "Command: " // Descriptive
```

### Changing Banner

**Location:** `src/ccp/ccp.c` in `main()`

**Current:**
```c
printf("\n");
printf("========================================\n");
printf("  JX Operating System\n");
printf("  Console Command Processor v1.0\n");
printf("========================================\n");
printf("\n");
printf("Type 'help' for available commands\n");
printf("\n");
```

**Customize as desired, then rebuild.**

### Maximum Command Length

**Location:** `src/ccp/ccp.c`

**Current:**
```c
#define CMD_MAX 128
```

**Change to desired size:**
```c
#define CMD_MAX 256  // Longer commands
#define CMD_MAX 64   // Shorter (save memory)
```

**Note:** Must rebuild after changes.

---

## Technical Details

### Source Code

**Main File:** `src/ccp/ccp.c` (~7.7 KB compiled)

**Dependencies:**
- `stdio.h` - printf, gets, putchar
- `string.h` - strcmp, strtok
- `bdos.h` - bdos(), bdos_gettpa(), bdos_getmem()
- `stdlib.h` - heap_used(), heap_available()

**Build:**
```bash
make ccp
```

**Output:**
- `build/ccp/ccp.hex` - Intel HEX format
- `build/ccp/ccp.bin` - Raw binary
- `build/ccp/ccp.lst` - Assembly listing

### Entry Point

```c
int main(void) {
    // Display banner
    // Main command loop
    return 0;
}
```

### Command Structure

```c
typedef struct {
    char *name;      // Command name
    void (*func)();  // Handler function
    char *help;      // Help text
} command_t;
```

Current implementation uses if-else chain for simplicity and size.

### read_line() Function

```c
char *read_line(char *buf, int max_len);
```

**Features:**
- Character echo
- Backspace support (visual erase)
- Line termination on CR or LF
- Buffer overflow protection
- Returns pointer to buffer

---

## Future Enhancements

### Planned Features

1. **Command History**
   - Up/Down arrows to recall commands
   - Limited history buffer (10-20 commands)

2. **Tab Completion**
   - Complete filenames from disk
   - Complete built-in command names

3. **Wildcards**
   - `*` and `?` patterns for file matching
   - Example: `dir *.txt`

4. **Redirection**
   - `>` output to file
   - `<` input from file
   - `|` pipes between programs

5. **Environment Variables**
   - PATH for program search
   - HOME for user directory
   - Custom variables

6. **Aliases**
   - User-defined command shortcuts
   - Example: `alias ll="dir -l"`

7. **Script Support**
   - Batch files (.bat)
   - Simple scripting language
   - Conditional execution

### Limitations

**Current:**
- No command history
- No tab completion
- No wildcards
- No redirection/pipes
- No environment variables
- No script execution
- Fixed command buffer (128 bytes)
- Case-sensitive commands

---

## Troubleshooting

### CCP doesn't start

**Possible causes:**
1. BIOS not built with CCP integration
2. CCP binary not included in system image
3. BIOS boot sequence not modified

**Solution:**
```bash
make clean
make all
```

### Commands not recognized

**Check:**
- Command spelling (case-sensitive)
- Use `help` to see available commands
- Built-in commands only (external not yet supported)

### Backspace not working

**Possible causes:**
- Terminal not recognizing backspace character
- Different backspace code (0x08 vs 0x7F)

**Note:** CCP handles both 0x08 and 0x7F

### Memory values seem wrong

**Check:**
- BDOS implementation (might be stub)
- Memory configuration (32/48/64 KB)
- Heap allocation in your programs

---

## See Also

- **Programming Guide:** `PROGRAMMING_C.md`
- **C Library:** `C_LIBRARY.md`
- **Build System:** `BUILD_SYSTEM.md`
- **Toolchain:** `TOOLCHAIN.md`

---

*Last Updated: 2026-01-29*
*JX Operating System - CCP Guide*
