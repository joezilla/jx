#include "stdlib.h"

// Convert signed integer to string in given base
// Returns pointer to the string (same as str parameter)
char *itoa(int value, char *str, int base) {
    char *ptr = str;
    int negative = 0;

    // Handle negative numbers (only for base 10)
    if (value < 0 && base == 10) {
        negative = 1;
        value = -value;
    }

    // Convert using utoa
    utoa((uint16_t)value, negative ? str + 1 : str, base);

    // Add negative sign if needed
    if (negative) {
        *str = '-';
    }

    return str;
}
