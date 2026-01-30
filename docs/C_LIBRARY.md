# JX C Library Reference

Complete reference for the JX Operating System C library (libjx.lib).

## Table of Contents

- [Library Overview](#library-overview)
- [stdio.h - Standard Input/Output](#stdioh---standard-inputoutput)
- [string.h - String Manipulation](#stringh---string-manipulation)
- [stdlib.h - Standard Library](#stdlibh---standard-library)
- [bdos.h - System Interface](#bdosh---system-interface)
- [Implementation Notes](#implementation-notes)

---

## Library Overview

### Components

| Module | Functions | Size | Purpose |
|--------|-----------|------|---------|
| crt0 | Runtime | ~200B | Program startup/exit |
| stdio | 6 functions | ~2KB | Console I/O and formatting |
| string | 16 functions | ~1.5KB | String and memory operations |
| stdlib | 8 functions | ~800B | Memory allocation and conversion |
| bdos | 6 wrappers | ~300B | System call interface |

**Total Library Size:** ~20KB (when all modules used)

### Header Files

```c
#include <stdio.h>    // Standard I/O
#include <string.h>   // String operations
#include <stdlib.h>   // Memory allocation, conversion
#include <stddef.h>   // size_t, NULL
#include <stdint.h>   // uint8_t, uint16_t, int16_t
#include <stdarg.h>   // va_list (for printf)
```

**BDOS Interface:**
```c
#include "../clib/bdos/bdos.h"  // Direct BDOS calls
```

---

## stdio.h - Standard Input/Output

### Constants

```c
#define EOF (-1)
```

### Functions

#### putchar

```c
int putchar(int c);
```

**Description:** Outputs a single character to the console.

**Parameters:**
- `c` - Character to output (only low byte used)

**Returns:** The character written, or EOF on error

**Notes:**
- Automatically converts `\n` to `\r\n` (CR+LF)
- Uses BDOS function 0x02 (CONOUT)
- Blocks until character is written

**Example:**
```c
putchar('H');
putchar('i');
putchar('\n');
// Output: Hi<newline>
```

---

#### getchar

```c
int getchar(void);
```

**Description:** Reads a single character from the console.

**Returns:** Character read (0-255), or EOF on error

**Notes:**
- Waits for keyboard input (blocking)
- Uses BDOS function 0x01 (CONIN)
- Character is echoed to console by BDOS

**Example:**
```c
int c = getchar();
if (c != EOF) {
    printf("You typed: %c\n", c);
}
```

---

#### puts

```c
int puts(const char *s);
```

**Description:** Outputs a string followed by a newline.

**Parameters:**
- `s` - Null-terminated string to output

**Returns:** Non-negative on success, EOF on error

**Notes:**
- Automatically appends newline
- More efficient than `printf("%s\n", s)`
- Safe for NULL pointer (no output)

**Example:**
```c
puts("Hello, World!");
// Output: Hello, World!<newline>
```

---

#### gets

```c
char *gets(char *s);
```

**Description:** Reads a line from console with editing support.

**Parameters:**
- `s` - Buffer to store input (must be large enough)

**Returns:** Pointer to `s`, or NULL on EOF

**Notes:**
- **WARNING:** Unsafe - no bounds checking (deprecated in C11)
- Supports backspace/delete for editing
- Echoes characters as typed
- Stops at newline or carriage return
- Null-terminates the string
- For safety, use a large buffer (128+ bytes)

**Example:**
```c
char buffer[128];
printf("Enter name: ");
if (gets(buffer)) {
    printf("Hello, %s!\n", buffer);
}
```

---

#### printf

```c
int printf(const char *format, ...);
```

**Description:** Formatted output to console.

**Parameters:**
- `format` - Format string with conversion specifiers
- `...` - Variable arguments matching format specifiers

**Returns:** Number of characters written (approximate)

**Supported Format Specifiers:**

| Spec | Type | Description | Example |
|------|------|-------------|---------|
| `%d` | int | Signed decimal | `-42` |
| `%i` | int | Signed decimal | `-42` |
| `%u` | unsigned | Unsigned decimal | `65535` |
| `%x` | unsigned | Hex (lowercase) | `ff` |
| `%X` | unsigned | Hex (lowercase*) | `ff` |
| `%o` | unsigned | Octal | `177` |
| `%c` | int | Character | `A` |
| `%s` | char* | String | `hello` |
| `%%` | - | Literal % | `%` |

*Note: %X produces lowercase (same as %x) in current implementation

**Field Width:** Not supported
**Precision:** Not supported
**Flags:** Not supported

**Notes:**
- Minimal implementation optimized for size
- Uses putchar() internally
- No buffering - output is immediate
- NULL string pointers print as `(null)`

**Examples:**
```c
// Basic types
printf("Number: %d\n", 42);          // Number: 42
printf("Hex: 0x%x\n", 255);          // Hex: 0xff
printf("Char: %c\n", 'A');           // Char: A
printf("String: %s\n", "Hello");     // String: Hello

// Multiple arguments
printf("%s = %d (0x%x)\n", "Answer", 42, 42);
// Output: Answer = 42 (0x2a)

// Special cases
printf("100%% complete\n");          // 100% complete
printf("Value: %d\n", 0);            // Value: 0
printf("Unsigned: %u\n", 65535);     // Unsigned: 65535
```

---

## string.h - String Manipulation

### String Length

#### strlen

```c
size_t strlen(const char *s);
```

**Description:** Calculate length of string.

**Parameters:**
- `s` - Null-terminated string

**Returns:** Number of characters before null terminator

**Notes:**
- Returns 0 for NULL pointer
- Does not count the null terminator
- O(n) time complexity

**Example:**
```c
size_t len = strlen("Hello");  // len = 5
```

---

### String Copy

#### strcpy

```c
char *strcpy(char *dest, const char *src);
```

**Description:** Copy string from src to dest.

**Parameters:**
- `dest` - Destination buffer (must be large enough)
- `src` - Source string

**Returns:** Pointer to dest

**Notes:**
- Copies until null terminator (inclusive)
- **WARNING:** No bounds checking - buffer overflow risk
- Undefined behavior if dest and src overlap
- Returns dest to allow chaining

**Example:**
```c
char buffer[20];
strcpy(buffer, "Hello");
// buffer now contains "Hello"
```

---

#### strncpy

```c
char *strncpy(char *dest, const char *src, size_t n);
```

**Description:** Copy at most n characters from src to dest.

**Parameters:**
- `dest` - Destination buffer
- `src` - Source string
- `n` - Maximum number of characters to copy

**Returns:** Pointer to dest

**Notes:**
- If src is shorter than n, pads dest with null bytes
- If src is n or longer, dest may not be null-terminated
- Always manually add null terminator for safety
- Safer than strcpy but still requires caution

**Example:**
```c
char buffer[20];
strncpy(buffer, "Hello, World!", 5);
buffer[5] = '\0';  // Ensure null termination
// buffer now contains "Hello"
```

---

### String Comparison

#### strcmp

```c
int strcmp(const char *s1, const char *s2);
```

**Description:** Compare two strings lexicographically.

**Parameters:**
- `s1` - First string
- `s2` - Second string

**Returns:**
- `< 0` if s1 < s2
- `0` if s1 == s2
- `> 0` if s1 > s2

**Notes:**
- Compares using unsigned character values
- Case-sensitive comparison
- Returns 0 for two NULL pointers
- Compares until first difference or null terminator

**Example:**
```c
if (strcmp(input, "quit") == 0) {
    printf("Exiting...\n");
}
```

---

#### strncmp

```c
int strncmp(const char *s1, const char *s2, size_t n);
```

**Description:** Compare at most n characters of two strings.

**Parameters:**
- `s1` - First string
- `s2` - Second string
- `n` - Maximum number of characters to compare

**Returns:** Same as strcmp

**Notes:**
- Stops at n characters or null terminator, whichever comes first
- Returns 0 if n is 0
- Useful for prefix matching

**Example:**
```c
if (strncmp(command, "help", 4) == 0) {
    show_help();
}
```

---

### String Concatenation

#### strcat

```c
char *strcat(char *dest, const char *src);
```

**Description:** Append src string to end of dest string.

**Parameters:**
- `dest` - Destination string (must have space for result)
- `src` - Source string to append

**Returns:** Pointer to dest

**Notes:**
- Finds end of dest (first null terminator)
- Copies src starting at that position
- **WARNING:** No bounds checking - buffer overflow risk
- Dest must have enough space for both strings plus null

**Example:**
```c
char buffer[20] = "Hello";
strcat(buffer, " World");
// buffer now contains "Hello World"
```

---

#### strncat

```c
char *strncat(char *dest, const char *src, size_t n);
```

**Description:** Append at most n characters of src to dest.

**Parameters:**
- `dest` - Destination string
- `src` - Source string
- `n` - Maximum characters to append

**Returns:** Pointer to dest

**Notes:**
- Always null-terminates the result
- Safer than strcat but still requires care
- Destination must have room for n + 1 characters beyond current length

**Example:**
```c
char buffer[20] = "Hello";
strncat(buffer, " World!", 3);
// buffer now contains "Hello Wo"
```

---

### String Search

#### strchr

```c
char *strchr(const char *s, int c);
```

**Description:** Find first occurrence of character in string.

**Parameters:**
- `s` - String to search
- `c` - Character to find (only low byte used)

**Returns:** Pointer to first occurrence, or NULL if not found

**Notes:**
- Returns pointer to null terminator if c is '\0'
- Returns NULL for NULL string pointer

**Example:**
```c
char *p = strchr("Hello", 'e');
if (p) {
    printf("Found at position: %d\n", p - "Hello");
    // Output: Found at position: 1
}
```

---

#### strrchr

```c
char *strrchr(const char *s, int c);
```

**Description:** Find last occurrence of character in string.

**Parameters:**
- `s` - String to search
- `c` - Character to find

**Returns:** Pointer to last occurrence, or NULL if not found

**Notes:**
- Scans entire string to find last match
- Returns pointer to null terminator if c is '\0'

**Example:**
```c
char *p = strrchr("Hello", 'l');
if (p) {
    printf("Last 'l' at position: %d\n", p - "Hello");
    // Output: Last 'l' at position: 3
}
```

---

#### strtok

```c
char *strtok(char *str, const char *delim);
```

**Description:** Tokenize string using delimiters.

**Parameters:**
- `str` - String to tokenize (NULL for subsequent calls)
- `delim` - String containing delimiter characters

**Returns:** Pointer to next token, or NULL if no more tokens

**Notes:**
- **Modifies original string** (replaces delimiters with '\0')
- Maintains internal state between calls
- First call: pass string to tokenize
- Subsequent calls: pass NULL
- Thread-unsafe (uses static variable)

**Example:**
```c
char input[] = "one,two,three";
char *token = strtok(input, ",");
while (token) {
    printf("Token: %s\n", token);
    token = strtok(NULL, ",");
}
// Output:
// Token: one
// Token: two
// Token: three
```

---

### Memory Operations

#### memcpy

```c
void *memcpy(void *dest, const void *src, size_t n);
```

**Description:** Copy n bytes from src to dest.

**Parameters:**
- `dest` - Destination buffer
- `src` - Source buffer
- `n` - Number of bytes to copy

**Returns:** Pointer to dest

**Notes:**
- **WARNING:** Undefined behavior if regions overlap
- Use memmove() for overlapping regions
- Efficient byte-by-byte copy
- Works with any data type

**Example:**
```c
char dest[10];
memcpy(dest, "Hello", 6);  // Copy "Hello\0"
```

---

#### memmove

```c
void *memmove(void *dest, const void *src, size_t n);
```

**Description:** Copy n bytes from src to dest (handles overlap).

**Parameters:**
- `dest` - Destination buffer
- `src` - Source buffer
- `n` - Number of bytes to copy

**Returns:** Pointer to dest

**Notes:**
- Safe for overlapping regions
- Chooses copy direction based on pointer relationship
- Slightly slower than memcpy due to overlap check

**Example:**
```c
char buffer[10] = "1234567890";
memmove(buffer + 2, buffer, 5);
// buffer now contains "1212345890"
```

---

#### memset

```c
void *memset(void *s, int c, size_t n);
```

**Description:** Fill n bytes of memory with constant byte.

**Parameters:**
- `s` - Memory region to fill
- `c` - Byte value to use (only low byte used)
- `n` - Number of bytes to fill

**Returns:** Pointer to s

**Notes:**
- Sets each byte to low byte of c
- Useful for zeroing memory
- Works with any data type

**Examples:**
```c
char buffer[100];
memset(buffer, 0, sizeof(buffer));     // Zero buffer
memset(buffer, 'A', 10);               // Fill with 'A'
```

---

#### memcmp

```c
int memcmp(const void *s1, const void *s2, size_t n);
```

**Description:** Compare n bytes of two memory regions.

**Parameters:**
- `s1` - First memory region
- `s2` - Second memory region
- `n` - Number of bytes to compare

**Returns:**
- `< 0` if s1 < s2
- `0` if s1 == s2
- `> 0` if s1 > s2

**Notes:**
- Compares unsigned byte values
- Stops at first difference
- Returns 0 if n is 0

**Example:**
```c
if (memcmp(buffer1, buffer2, 10) == 0) {
    printf("First 10 bytes are identical\n");
}
```

---

## stdlib.h - Standard Library

### Memory Allocation

#### malloc

```c
void *malloc(size_t size);
```

**Description:** Allocate memory from heap.

**Parameters:**
- `size` - Number of bytes to allocate

**Returns:** Pointer to allocated memory, or NULL on failure

**Notes:**
- Uses simple bump allocator
- 2-byte alignment for better performance
- Returns NULL if size is 0
- Returns NULL if heap exhausted
- 256-byte safety margin from stack

**Implementation Details:**
- No per-allocation overhead
- No ability to free individual blocks
- Extremely fast O(1) allocation
- Ideal for programs that allocate at startup

**Example:**
```c
char *buffer = malloc(256);
if (!buffer) {
    printf("Out of memory!\n");
    return -1;
}
// Use buffer...
```

---

#### calloc

```c
void *calloc(size_t nmemb, size_t size);
```

**Description:** Allocate and zero-initialize memory.

**Parameters:**
- `nmemb` - Number of elements
- `size` - Size of each element

**Returns:** Pointer to zeroed memory, or NULL on failure

**Notes:**
- Allocates `nmemb * size` bytes
- All bytes set to 0
- Checks for multiplication overflow
- More convenient than malloc + memset

**Example:**
```c
int *array = (int *)calloc(10, sizeof(int));
if (array) {
    // All elements are guaranteed to be 0
    for (int i = 0; i < 10; i++) {
        printf("%d ", array[i]);  // Prints: 0 0 0 0 0 0 0 0 0 0
    }
}
```

---

#### realloc

```c
void *realloc(void *ptr, size_t size);
```

**Description:** Resize previously allocated memory.

**Parameters:**
- `ptr` - Pointer to previously allocated memory (or NULL)
- `size` - New size in bytes

**Returns:** Pointer to resized memory, or NULL on failure

**Notes:**
- If ptr is NULL, behaves like malloc(size)
- If size is 0, behaves like free(ptr)
- **Always allocates new memory** (bump allocator limitation)
- Copies data to new location
- Old pointer becomes invalid (but memory not freed)
- Old memory wasted until program exit

**Example:**
```c
char *buf = malloc(100);
strcpy(buf, "Hello");

// Need more space
buf = realloc(buf, 200);
if (!buf) {
    printf("Realloc failed!\n");
}
// Content preserved: "Hello"
```

---

#### free

```c
void free(void *ptr);
```

**Description:** Free allocated memory (stub).

**Parameters:**
- `ptr` - Pointer to memory to free

**Returns:** None

**Notes:**
- **This is a NO-OP** in current implementation
- Bump allocator cannot free individual blocks
- Memory is reclaimed when program exits
- Provided for API compatibility
- Safe to call (does nothing)

**Example:**
```c
char *buf = malloc(100);
// Use buf...
free(buf);  // Does nothing, but safe to call
```

---

### Heap Statistics (JX Extensions)

#### heap_used

```c
size_t heap_used(void);
```

**Description:** Get number of bytes currently allocated.

**Returns:** Bytes allocated from heap

**Notes:**
- JX-specific extension (not standard C)
- Returns 0 if heap not initialized
- Includes alignment padding
- Useful for monitoring memory usage

---

#### heap_available

```c
size_t heap_available(void);
```

**Description:** Get number of bytes still available for allocation.

**Returns:** Bytes remaining in heap

**Notes:**
- JX-specific extension (not standard C)
- Includes safety margin to stack
- Returns 0 if heap exhausted or not initialized
- Useful before large allocations

**Example:**
```c
printf("Memory status:\n");
printf("  Used:      %u bytes\n", heap_used());
printf("  Available: %u bytes\n", heap_available());

if (heap_available() < 1024) {
    printf("WARNING: Low memory!\n");
}
```

---

### Number Conversion

#### itoa

```c
char *itoa(int value, char *str, int base);
```

**Description:** Convert signed integer to string.

**Parameters:**
- `value` - Integer to convert
- `str` - Buffer for result (must be large enough)
- `base` - Number base (2-36)

**Returns:** Pointer to str

**Notes:**
- Handles negative numbers (base 10 only)
- Uses lowercase letters for bases > 10
- Requires ~20-byte buffer for worst case
- No bounds checking - ensure buffer is large enough

**Example:**
```c
char buf[20];
itoa(255, buf, 16);
printf("Hex: %s\n", buf);  // Hex: ff

itoa(-42, buf, 10);
printf("Dec: %s\n", buf);  // Dec: -42
```

---

#### utoa

```c
char *utoa(uint16_t value, char *str, int base);
```

**Description:** Convert unsigned integer to string.

**Parameters:**
- `value` - Unsigned integer to convert
- `str` - Buffer for result
- `base` - Number base (2-36)

**Returns:** Pointer to str

**Notes:**
- Always positive (unsigned)
- Uses lowercase letters for bases > 10
- Requires ~17-byte buffer for worst case
- Faster than itoa for positive numbers

**Example:**
```c
char buf[20];
utoa(65535, buf, 10);
printf("Max uint16: %s\n", buf);  // Max uint16: 65535

utoa(255, buf, 2);
printf("Binary: %s\n", buf);  // Binary: 11111111
```

---

#### atoi

```c
int atoi(const char *str);
```

**Description:** Convert string to integer.

**Parameters:**
- `str` - String to convert

**Returns:** Integer value, or 0 on error

**Notes:**
- Skips leading whitespace
- Stops at first non-digit character
- Handles optional leading minus sign
- Returns 0 for invalid input
- No error indication (can't distinguish 0 from error)

**Example:**
```c
int value = atoi("42");     // value = 42
int neg = atoi("-100");     // neg = -100
int zero = atoi("abc");     // zero = 0 (error)
```

---

## bdos.h - System Interface

### BDOS Function Numbers

```c
#define BDOS_RESET      0x00   // System reset (warm boot)
#define BDOS_CONIN      0x01   // Console input
#define BDOS_CONOUT     0x02   // Console output
#define BDOS_PRINT      0x09   // Print $ terminated string
#define BDOS_CONST      0x0B   // Console status
#define BDOS_GETVER     0x0C   // Get version number
#define BDOS_GETTPA     0x31   // Get TPA top (JX extension)
#define BDOS_GETMEM     0x32   // Get memory size (JX extension)
```

### Functions

#### bdos

```c
uint16_t bdos(uint8_t func, uint16_t arg);
```

**Description:** Direct BDOS system call.

**Parameters:**
- `func` - BDOS function number
- `arg` - 16-bit argument (usage depends on function)

**Returns:** 16-bit result (meaning depends on function)

**Notes:**
- Low-level interface to BDOS
- Function number goes in C register
- Argument goes in DE register pair
- Result returned in HL register pair

**Example:**
```c
// Get BDOS version
uint16_t ver = bdos(BDOS_GETVER, 0);
printf("BDOS %u.%u\n", ver >> 8, ver & 0xFF);
```

---

#### bdos_conin

```c
uint8_t bdos_conin(void);
```

**Description:** Read character from console.

**Returns:** Character read (0-255)

**Notes:**
- Blocks until character available
- Character is echoed
- Wrapper for bdos(BDOS_CONIN, 0)

---

#### bdos_conout

```c
void bdos_conout(char c);
```

**Description:** Write character to console.

**Parameters:**
- `c` - Character to output

**Notes:**
- Outputs single character
- Wrapper for bdos(BDOS_CONOUT, c)
- Used by putchar()

---

#### bdos_const

```c
uint8_t bdos_const(void);
```

**Description:** Check console status.

**Returns:**
- 0xFF if character ready
- 0x00 if no character ready

**Notes:**
- Non-blocking
- Useful for polling input

**Example:**
```c
if (bdos_const()) {
    char c = bdos_conin();
    printf("Got: %c\n", c);
}
```

---

#### bdos_gettpa

```c
uint16_t bdos_gettpa(void);
```

**Description:** Get TPA top address.

**Returns:** Address of TPA top (typically 0xF400-0xF500)

**Notes:**
- JX extension (BDOS function 0x31)
- Useful for calculating available memory
- Used by crt0 for stack setup

**Example:**
```c
uint16_t tpa_top = bdos_gettpa();
uint16_t tpa_size = tpa_top - 0x0100;
printf("TPA: %u bytes\n", tpa_size);
```

---

#### bdos_getmem

```c
uint16_t bdos_getmem(void);
```

**Description:** Get total system memory size.

**Returns:** Memory size in kilobytes

**Notes:**
- JX extension (BDOS function 0x32)
- Typically returns 32, 48, or 64

**Example:**
```c
printf("System RAM: %u KB\n", bdos_getmem());
```

---

## Implementation Notes

### Compiler

**SDCC (Small Device C Compiler) 4.x**
- Target: Z80/8080 architecture
- Optimization: Size-optimized (`--opt-code-size`)
- Standard: C11 (`--std-c11`)

### Calling Convention

SDCC uses its own calling convention for Z80:
- First parameter may be passed in registers (HL, DE, BC)
- Additional parameters on stack
- Return value in HL (16-bit) or L (8-bit)

Special attributes:
- `__naked` - No prologue/epilogue
- `__z88dk_fastcall` - Fast call for single parameter

### Memory Model

**Code Location:** 0x0100 (TPA_BASE)
**Data Location:** Follows code
**Stack:** Top of TPA, grows downward
**Heap:** Follows BSS, grows upward

### Size Optimization

Library is optimized for small code size:
- Minimal printf implementation
- Inline assembly for BDOS calls
- Shared code where possible
- No buffering

### Thread Safety

**Not thread-safe:**
- strtok() - uses static variable

**Thread-safe:**
- All other functions (no threads in JX currently)

---

*Last Updated: 2026-01-29*
*JX Operating System - C Library Reference*
