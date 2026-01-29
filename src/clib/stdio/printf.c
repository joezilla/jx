#include "stdio.h"
#include "../stdlib/stdlib.h"
#include <stdarg.h>

// Helper to print a string
static void print_string(const char *s) {
    if (!s) s = "(null)";
    while (*s) {
        putchar(*s++);
    }
}

// Helper to print a number
static void print_number(int value, int base) {
    char buf[20];  // Enough for 16-bit numbers in any base >= 2
    itoa(value, buf, base);
    print_string(buf);
}

// Helper to print an unsigned number
static void print_unsigned(uint16_t value, int base) {
    char buf[20];
    utoa(value, buf, base);
    print_string(buf);
}

// Minimal printf implementation
// Supports: %d, %u, %x, %X, %o, %c, %s, %%
int printf(const char *format, ...) {
    va_list args;
    int count = 0;
    const char *p;

    if (!format) return 0;

    va_start(args, format);

    for (p = format; *p != '\0'; p++) {
        if (*p == '%') {
            p++;  // Skip '%'

            switch (*p) {
                case 'd':  // Signed decimal integer
                case 'i':
                    print_number(va_arg(args, int), 10);
                    break;

                case 'u':  // Unsigned decimal integer
                    print_unsigned(va_arg(args, unsigned int), 10);
                    break;

                case 'x':  // Unsigned hexadecimal (lowercase)
                    print_unsigned(va_arg(args, unsigned int), 16);
                    break;

                case 'X':  // Unsigned hexadecimal (uppercase) - we'll use lowercase
                    print_unsigned(va_arg(args, unsigned int), 16);
                    break;

                case 'o':  // Unsigned octal
                    print_unsigned(va_arg(args, unsigned int), 8);
                    break;

                case 'c':  // Character
                    putchar(va_arg(args, int));
                    count++;
                    break;

                case 's':  // String
                    print_string(va_arg(args, char *));
                    break;

                case '%':  // Literal '%'
                    putchar('%');
                    count++;
                    break;

                case '\0':  // Format string ends with '%'
                    p--;  // Back up so outer loop will exit
                    break;

                default:  // Unknown format specifier
                    putchar('%');
                    putchar(*p);
                    count += 2;
                    break;
            }
        } else {
            putchar(*p);
            count++;
        }
    }

    va_end(args);
    return count;
}
