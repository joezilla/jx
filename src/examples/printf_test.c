#include <stdio.h>

int main(void) {
    int num = 42;
    int neg = -123;
    unsigned int hex = 0xDEAD;
    char ch = 'X';
    char *str = "World";

    puts("Printf Format Specifier Test");
    puts("============================");
    putchar('\n');

    // Test %s - string
    printf("String test: Hello, %s!\n", str);

    // Test %d - signed decimal
    printf("Decimal test: %d\n", num);
    printf("Negative test: %d\n", neg);

    // Test %u - unsigned decimal
    printf("Unsigned test: %u\n", 65535);

    // Test %x - hexadecimal
    printf("Hex test: 0x%x\n", hex);
    printf("Hex value: 0x%x = %d\n", 255, 255);

    // Test %o - octal
    printf("Octal test: %o (octal) = %d (decimal)\n", 64, 64);

    // Test %c - character
    printf("Char test: %c\n", ch);

    // Test %% - literal percent
    printf("Percent test: 100%% complete\n");

    // Combined test
    printf("\nCombined: %s = %d (0x%x)\n", "Answer", num, num);

    // Edge cases
    printf("\nEdge cases:\n");
    printf("Zero: %d\n", 0);
    printf("Max int: %d\n", 32767);
    printf("Min int: %d\n", -32768);

    putchar('\n');
    puts("Test complete!");

    return 0;
}
