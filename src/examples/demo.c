#include <stdio.h>

int main(void) {
    int x, y, sum, product;

    printf("\n");
    printf("========================================\n");
    printf("  JX Operating System - C Demo\n");
    printf("========================================\n");
    printf("\n");

    // Show off different format specifiers
    printf("Memory addresses:\n");
    printf("  BIOS:   0x%x\n", 0xFD00);
    printf("  BDOS:   0x%x\n", 0xF500);
    printf("  TPA:    0x%x - 0x%x\n", 0x0100, 0xF400);
    printf("\n");

    // Simple arithmetic
    x = 15;
    y = 27;
    sum = x + y;
    product = x * y;

    printf("Arithmetic demonstration:\n");
    printf("  %d + %d = %d\n", x, y, sum);
    printf("  %d * %d = %d\n", x, y, product);
    printf("\n");

    // Number bases
    printf("Number 255 in different bases:\n");
    printf("  Decimal:     %d\n", 255);
    printf("  Hexadecimal: 0x%x\n", 255);
    printf("  Octal:       0%o\n", 255);
    printf("\n");

    // Character manipulation
    printf("Character test: %c%c%c%c%c\n", 'H', 'e', 'l', 'l', 'o');
    printf("\n");

    // String test
    printf("Compiled with SDCC %s for %s CPU\n", "4.x", "8080");
    printf("\n");

    printf("All tests passed!\n");
    printf("\n");

    return 0;
}
