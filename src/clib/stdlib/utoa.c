#include "stdlib.h"

// Convert unsigned integer to string in given base
// Returns pointer to the string (same as str parameter)
char *utoa(uint16_t value, char *str, int base) {
    char *ptr = str;
    char *ptr1 = str;
    char tmp_char;
    uint16_t tmp_value;

    // Validate base
    if (base < 2 || base > 36) {
        *str = '\0';
        return str;
    }

    // Handle zero specially
    if (value == 0) {
        *ptr++ = '0';
        *ptr = '\0';
        return str;
    }

    // Process individual digits
    do {
        tmp_value = value;
        value /= base;
        *ptr++ = "0123456789abcdefghijklmnopqrstuvwxyz"[tmp_value - value * base];
    } while (value);

    // Null terminate
    *ptr-- = '\0';

    // Reverse the string
    while (ptr1 < ptr) {
        tmp_char = *ptr;
        *ptr-- = *ptr1;
        *ptr1++ = tmp_char;
    }

    return str;
}
