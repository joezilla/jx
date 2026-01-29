#ifndef _STDIO_H
#define _STDIO_H

#include <stdint.h>
#include <stddef.h>

// EOF constant
#define EOF (-1)

// Console I/O
int putchar(int c);
int getchar(void);
int puts(const char *s);
char *gets(char *s);

// Formatted I/O
int printf(const char *format, ...);

#endif // _STDIO_H
