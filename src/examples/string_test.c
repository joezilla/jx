#include <stdio.h>
#include <string.h>

// Test helper
static int test_count = 0;
static int pass_count = 0;

void test(const char *name, int condition) {
    test_count++;
    if (condition) {
        pass_count++;
        printf("  [PASS] %s\n", name);
    } else {
        printf("  [FAIL] %s\n", name);
    }
}

int main(void) {
    char buf1[64];
    char buf2[64];
    char buf3[64];

    printf("\n");
    printf("========================================\n");
    printf("  String Library Test Suite\n");
    printf("========================================\n");
    printf("\n");

    // Test strlen
    printf("Testing strlen:\n");
    test("strlen empty", strlen("") == 0);
    test("strlen hello", strlen("Hello") == 5);
    test("strlen sentence", strlen("The quick brown fox") == 19);
    printf("\n");

    // Test strcpy
    printf("Testing strcpy:\n");
    strcpy(buf1, "Test");
    test("strcpy basic", strcmp(buf1, "Test") == 0);
    strcpy(buf1, "");
    test("strcpy empty", strcmp(buf1, "") == 0);
    printf("\n");

    // Test strncpy
    printf("Testing strncpy:\n");
    strncpy(buf1, "Hello", 64);
    test("strncpy full", strcmp(buf1, "Hello") == 0);
    strncpy(buf1, "World", 3);
    buf1[3] = '\0';
    test("strncpy partial", strcmp(buf1, "Wor") == 0);
    printf("\n");

    // Test strcmp
    printf("Testing strcmp:\n");
    test("strcmp equal", strcmp("abc", "abc") == 0);
    test("strcmp less", strcmp("abc", "abd") < 0);
    test("strcmp greater", strcmp("abd", "abc") > 0);
    test("strcmp prefix", strcmp("ab", "abc") < 0);
    printf("\n");

    // Test strncmp
    printf("Testing strncmp:\n");
    test("strncmp equal", strncmp("abc", "abc", 3) == 0);
    test("strncmp partial", strncmp("abc", "abd", 2) == 0);
    test("strncmp diff", strncmp("abc", "abd", 3) < 0);
    printf("\n");

    // Test strcat
    printf("Testing strcat:\n");
    strcpy(buf1, "Hello");
    strcat(buf1, " World");
    test("strcat basic", strcmp(buf1, "Hello World") == 0);
    strcpy(buf1, "");
    strcat(buf1, "Test");
    test("strcat to empty", strcmp(buf1, "Test") == 0);
    printf("\n");

    // Test strncat
    printf("Testing strncat:\n");
    strcpy(buf1, "Hello");
    strncat(buf1, " World", 3);
    test("strncat partial", strcmp(buf1, "Hello Wo") == 0);
    printf("\n");

    // Test strchr
    printf("Testing strchr:\n");
    test("strchr found", strchr("Hello", 'e') != NULL);
    test("strchr not found", strchr("Hello", 'x') == NULL);
    test("strchr position", strchr("Hello", 'l') == "Hello" + 2);
    printf("\n");

    // Test strrchr
    printf("Testing strrchr:\n");
    test("strrchr found", strrchr("Hello", 'l') != NULL);
    test("strrchr last", strrchr("Hello", 'l') == "Hello" + 3);
    test("strrchr not found", strrchr("Hello", 'x') == NULL);
    printf("\n");

    // Test memcpy
    printf("Testing memcpy:\n");
    strcpy(buf1, "Source");
    memcpy(buf2, buf1, 7);
    test("memcpy basic", strcmp(buf2, "Source") == 0);
    memcpy(buf3, "12345", 5);
    buf3[5] = '\0';
    test("memcpy bytes", strcmp(buf3, "12345") == 0);
    printf("\n");

    // Test memmove
    printf("Testing memmove:\n");
    strcpy(buf1, "1234567890");
    memmove(buf1 + 2, buf1, 5);
    buf1[7] = '\0';
    test("memmove overlap", strcmp(buf1, "1212345") == 0);
    printf("\n");

    // Test memset
    printf("Testing memset:\n");
    memset(buf1, 'A', 5);
    buf1[5] = '\0';
    test("memset char", strcmp(buf1, "AAAAA") == 0);
    memset(buf2, 0, 10);
    test("memset zero", buf2[0] == 0 && buf2[9] == 0);
    printf("\n");

    // Test memcmp
    printf("Testing memcmp:\n");
    test("memcmp equal", memcmp("abc", "abc", 3) == 0);
    test("memcmp less", memcmp("abc", "abd", 3) < 0);
    test("memcmp greater", memcmp("abd", "abc", 3) > 0);
    test("memcmp partial", memcmp("abc", "abd", 2) == 0);
    printf("\n");

    // Summary
    printf("========================================\n");
    printf("Results: %d/%d tests passed\n", pass_count, test_count);
    if (pass_count == test_count) {
        printf("All tests PASSED!\n");
    } else {
        printf("%d tests FAILED\n", test_count - pass_count);
    }
    printf("========================================\n");
    printf("\n");

    return (pass_count == test_count) ? 0 : 1;
}
