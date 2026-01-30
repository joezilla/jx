# Programming in C on JX Operating System

This guide covers writing, compiling, and running C programs on the JX Operating System for Intel 8080.

## Table of Contents

- [Getting Started](#getting-started)
- [Your First C Program](#your-first-c-program)
- [Available Library Functions](#available-library-functions)
- [Memory Layout](#memory-layout)
- [Building Programs](#building-programs)
- [Running Programs](#running-programs)
- [Best Practices](#best-practices)
- [Limitations](#limitations)
- [Examples](#examples)

---

## Getting Started

### Prerequisites

- SDCC (Small Device C Compiler) 4.x or later installed
- JX build environment set up
- Familiarity with C programming

### Installation

Install SDCC:

**macOS (Homebrew):**
```bash
brew install sdcc
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install sdcc
```

Verify installation:
```bash
sdcc --version
```

---

## Your First C Program

### Hello World

Create a file `hello.c`:

```c
#include <stdio.h>

int main(void) {
    printf("Hello from JX!\n");
    return 0;
}
```

### Build and Run

```bash
# Build the program
make build/examples/hello.hex

# Run in simulator (when available)
make run-example EXAMPLE=hello
```

---

## Available Library Functions

### Standard I/O (`<stdio.h>`)

**Console Output:**
```c
int putchar(int c);              // Output single character
int puts(const char *s);         // Output string with newline
int printf(const char *fmt, ...); // Formatted output
```

**Console Input:**
```c
int getchar(void);               // Read single character
char *gets(char *s);             // Read line (with backspace support)
```

**Supported printf Format Specifiers:**
- `%d, %i` - Signed decimal integer
- `%u` - Unsigned decimal integer
- `%x, %X` - Hexadecimal (lowercase/uppercase)
- `%o` - Octal
- `%c` - Character
- `%s` - String
- `%%` - Literal percent sign

**Example:**
```c
int count = 42;
printf("Count: %d (0x%x)\n", count, count);
// Output: Count: 42 (0x2a)
```

### String Functions (`<string.h>`)

**Length and Copy:**
```c
size_t strlen(const char *s);
char *strcpy(char *dest, const char *src);
char *strncpy(char *dest, const char *src, size_t n);
```

**Comparison:**
```c
int strcmp(const char *s1, const char *s2);
int strncmp(const char *s1, const char *s2, size_t n);
```

**Concatenation:**
```c
char *strcat(char *dest, const char *src);
char *strncat(char *dest, const char *src, size_t n);
```

**Search:**
```c
char *strchr(const char *s, int c);     // Find first occurrence
char *strrchr(const char *s, int c);    // Find last occurrence
char *strtok(char *str, const char *delim); // Tokenize string
```

**Memory Operations:**
```c
void *memcpy(void *dest, const void *src, size_t n);
void *memmove(void *dest, const void *src, size_t n);
void *memset(void *s, int c, size_t n);
int memcmp(const void *s1, const void *s2, size_t n);
```

### Memory Allocation (`<stdlib.h>`)

**Allocation Functions:**
```c
void *malloc(size_t size);              // Allocate memory
void *calloc(size_t nmemb, size_t size); // Allocate and zero
void *realloc(void *ptr, size_t size);  // Resize allocation
void free(void *ptr);                    // Free memory (stub)
```

**Heap Statistics (JX Extensions):**
```c
size_t heap_used(void);      // Bytes currently allocated
size_t heap_available(void); // Bytes still available
```

**Example:**
```c
char *buffer = malloc(256);
if (buffer) {
    strcpy(buffer, "Hello");
    printf("%s\n", buffer);
    free(buffer);  // Note: free is a stub in current implementation
}

printf("Heap used: %u bytes\n", heap_used());
```

**Important Notes:**
- Uses a simple bump allocator
- `free()` is a no-op (memory reclaimed on program exit)
- `realloc()` always allocates new memory and copies
- 256-byte safety margin maintained between heap and stack

### Number Conversion (`<stdlib.h>`)

```c
int atoi(const char *str);                    // String to integer
char *itoa(int value, char *str, int base);   // Integer to string
char *utoa(uint16_t value, char *str, int base); // Unsigned to string
```

**Example:**
```c
char buf[20];
itoa(255, buf, 16);   // Convert to hex
printf("0x%s\n", buf); // Output: 0xff
```

### BDOS Interface (`"../clib/bdos/bdos.h"`)

**Direct BDOS Calls:**
```c
uint16_t bdos(uint8_t func, uint16_t arg);
```

**Console I/O:**
```c
uint8_t bdos_conin(void);      // Read character
void bdos_conout(char c);       // Write character
void bdos_print(const char *s); // Print $-terminated string
uint8_t bdos_const(void);       // Console status
```

**Memory Queries:**
```c
uint16_t bdos_gettpa(void);     // Get TPA top address
uint16_t bdos_getmem(void);     // Get memory size in KB
```

**BDOS Function Numbers:**
```c
#define BDOS_RESET      0x00   // System reset (warm boot)
#define BDOS_CONIN      0x01   // Console input
#define BDOS_CONOUT     0x02   // Console output
#define BDOS_PRINT      0x09   // Print string
#define BDOS_CONST      0x0B   // Console status
#define BDOS_GETVER     0x0C   // Get version
// ... see bdos.h for complete list
```

---

## Memory Layout

### TPA (Transient Program Area)

For 64KB system configuration:

```
Address Range        Purpose                Size
-------------        -------                ----
0x0000 - 0x00FF     Page Zero (vectors)    256 bytes
0x0100 - 0xF4FF     TPA (your program)     ~62 KB
0xF500 - 0xF5FF     System Stack           256 bytes
0xF600 - 0xFDFF     BDOS                   2 KB
0xFE00 - 0xFFFF     BIOS                   512 bytes
```

### Program Memory Organization

Your program is loaded at **0x0100** with this layout:

```
0x0100              CODE segment (your code)
CODE_END            DATA segment (initialized globals)
DATA_END            BSS segment (uninitialized globals)
BSS_END             HEAP (grows upward via malloc)
...                 (gap - safety margin)
TPA_TOP - 256       STACK (grows downward)
TPA_TOP (0xF500)    End of TPA
```

**Stack Safety:**
- 256-byte margin maintained between heap and stack
- Prevents heap-stack collision
- Conservative to ensure system stability

### Memory Constraints

- **Maximum program size:** ~60 KB (code + data + heap + stack)
- **Heap space:** Dynamic, limited by TPA size minus program size
- **Stack space:** 256 bytes (adequate for normal usage)
- **No memory protection:** Careful programming required

---

## Building Programs

### Directory Structure

Place your C programs in:
```
src/examples/yourprogram.c
```

Or create a new directory:
```
src/myapp/myapp.c
```

### Build Commands

**Single program:**
```bash
make build/examples/yourprogram.hex
```

**All examples:**
```bash
make examples
```

**With verbose output:**
```bash
make build/examples/yourprogram.hex VERBOSE=1
```

### Build Process

The build system performs these steps:

1. **Compile** (.c → .rel)
   ```bash
   sdcc -mz80 --std-c11 --opt-code-size -c yourprogram.c
   ```

2. **Link** (.rel → .ihx)
   ```bash
   sdcc --code-loc 0x0100 --data-loc 0x8000 --no-std-crt0 \
        crt0.rel yourprogram.rel libjx.lib
   ```

3. **Convert** (.ihx → .hex/.bin)
   ```bash
   cp yourprogram.ihx yourprogram.hex
   makebin -p yourprogram.ihx yourprogram.bin
   ```

### Output Files

After building, you'll find:

- **yourprogram.hex** - Intel HEX format (for simulator)
- **yourprogram.bin** - Raw binary (for ROM/disk)
- **yourprogram.lst** - Assembly listing with C source
- **yourprogram.map** - Memory map
- **yourprogram.sym** - Symbol table

---

## Running Programs

### In Simulator

```bash
make run-example EXAMPLE=yourprogram
```

This runs the program in the cpmsim simulator from z80pack.

### On Hardware

1. Load the .hex file to your hardware
2. Program starts at address 0x0100
3. Requires BDOS at 0xF600 and BIOS at 0xFE00

### From CCP Shell

(When file I/O is implemented)

```
JX> yourprogram
```

The CCP will load and execute your program.

---

## Best Practices

### Memory Management

**DO:**
- Check malloc() return value
- Use heap_available() before large allocations
- Keep allocations reasonable (< 4KB typical)
- Prefer stack variables for small data

**DON'T:**
- Rely on free() (it's a no-op)
- Allocate and free in tight loops
- Assume unlimited memory
- Use excessive recursion (limited stack)

**Example:**
```c
void *buffer = malloc(1024);
if (!buffer) {
    printf("Out of memory!\n");
    return -1;
}
// Use buffer...
// Note: free(buffer) doesn't actually free memory
```

### Code Size Optimization

**Techniques:**
- Use `--opt-code-size` flag (default)
- Avoid inline functions
- Minimize use of printf (use puts when possible)
- Share code via functions
- Use local variables (stack) instead of global (data segment)

**Size Guidelines:**
- Simple programs: 1-2 KB
- Medium programs: 4-8 KB
- Complex programs: 10-15 KB
- Leave room for heap/stack

### String Handling

**Safe patterns:**
```c
// Use strncpy for safety
strncpy(dest, src, sizeof(dest) - 1);
dest[sizeof(dest) - 1] = '\0';

// Prefer strncat over strcat
strncat(dest, src, sizeof(dest) - strlen(dest) - 1);

// Use sizeof for bounds
char buf[64];
printf("Size: %u\n", (unsigned)sizeof(buf));
```

### Error Handling

```c
// Check all allocations
char *buf = malloc(size);
if (!buf) {
    printf("ERROR: malloc failed\n");
    return -1;
}

// Validate input
if (!filename || !*filename) {
    printf("ERROR: Invalid filename\n");
    return -1;
}

// Return meaningful codes
return 0;   // Success
return 1;   // General error
return -1;  // Specific error
```

---

## Limitations

### Current Restrictions

1. **No free()** - Bump allocator doesn't support individual deallocation
2. **No file I/O** - Requires BDOS disk implementation (future)
3. **No floating point** - 8080 has no FPU, software FP is large
4. **Limited recursion** - 256-byte stack
5. **No command-line args** - Not yet implemented in crt0
6. **No setjmp/longjmp** - Not implemented

### Workarounds

**Instead of free():**
- Design for single allocation at start
- Use automatic (stack) variables
- Reset program state on re-run

**Instead of file I/O:**
- Use console I/O
- Implement custom protocols
- Wait for BDOS disk support

**Instead of floating point:**
- Use fixed-point arithmetic
- Scale integers (e.g., store cents instead of dollars)
- Use lookup tables

---

## Examples

### Example 1: Memory Information

```c
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    printf("Memory Information:\n");
    printf("  Heap used:      %u bytes\n", heap_used());
    printf("  Heap available: %u bytes\n", heap_available());

    // Allocate some memory
    char *buf = malloc(1024);
    if (buf) {
        printf("\nAfter malloc(1024):\n");
        printf("  Heap used:      %u bytes\n", heap_used());
        printf("  Heap available: %u bytes\n", heap_available());
    }

    return 0;
}
```

### Example 2: String Processing

```c
#include <stdio.h>
#include <string.h>

int main(void) {
    char input[128];
    char *token;
    int count = 0;

    printf("Enter words separated by spaces: ");
    gets(input);

    // Tokenize the input
    token = strtok(input, " ");
    while (token) {
        count++;
        printf("Word %d: %s\n", count, token);
        token = strtok(NULL, " ");
    }

    printf("Total words: %d\n", count);
    return 0;
}
```

### Example 3: Number Formatting

```c
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    int value = 255;
    char buf[20];

    // Decimal
    printf("Decimal: %d\n", value);

    // Hexadecimal (via printf)
    printf("Hex (printf): 0x%x\n", value);

    // Hexadecimal (via itoa)
    itoa(value, buf, 16);
    printf("Hex (itoa): 0x%s\n", buf);

    // Binary (manual)
    itoa(value, buf, 2);
    printf("Binary: 0b%s\n", buf);

    // Octal
    printf("Octal: 0%o\n", value);

    return 0;
}
```

### Example 4: Dynamic Arrays

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    int i;
    int *numbers;
    char *names;

    // Allocate array of integers
    numbers = (int *)malloc(10 * sizeof(int));
    if (!numbers) {
        printf("Allocation failed!\n");
        return 1;
    }

    // Fill with squares
    for (i = 0; i < 10; i++) {
        numbers[i] = i * i;
    }

    // Display
    for (i = 0; i < 10; i++) {
        printf("%d^2 = %d\n", i, numbers[i]);
    }

    // Allocate string buffer
    names = (char *)calloc(100, 1);  // Zero-initialized
    if (names) {
        strcpy(names, "Hello, JX!");
        printf("\nString: %s\n", names);
    }

    return 0;
}
```

### Example 5: BDOS Integration

```c
#include <stdio.h>
#include "../clib/bdos/bdos.h"

int main(void) {
    uint16_t version;
    uint16_t tpa_top;
    uint16_t mem_kb;

    // Get BDOS version
    version = bdos(BDOS_GETVER, 0);
    printf("BDOS Version: %u.%u\n",
           (version >> 8) & 0xFF,
           version & 0xFF);

    // Get memory information
    tpa_top = bdos_gettpa();
    mem_kb = bdos_getmem();

    printf("Memory: %u KB\n", mem_kb);
    printf("TPA Top: 0x%04X\n", tpa_top);
    printf("TPA Size: %u bytes\n", tpa_top - 0x0100);

    return 0;
}
```

---

## Additional Resources

- **C Library Reference:** See `C_LIBRARY.md`
- **Build System:** See `BUILD_SYSTEM.md`
- **CCP Shell:** See `CCP_GUIDE.md`
- **Toolchain:** See `TOOLCHAIN.md`
- **SDCC Manual:** https://sdcc.sourceforge.net/doc/sdccman.pdf

---

## Getting Help

**Compiler Errors:**
- Check include paths: `-I$(CLIB_DIR)`
- Verify function prototypes match
- Use `--fverbose-asm` for detailed output

**Linker Errors:**
- Ensure crt0.rel is linked first
- Check for undefined symbols in .map file
- Verify library order: crt0, program, libjx

**Runtime Issues:**
- Check stack usage (avoid deep recursion)
- Monitor heap with heap_available()
- Verify pointer validity before use
- Check return values from functions

---

*Last Updated: 2026-01-29*
*JX Operating System - C Programming Guide*
