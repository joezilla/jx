#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    char *buf1, *buf2, *buf3;
    int *nums;
    int i;

    printf("\n");
    printf("========================================\n");
    printf("  Memory Allocation Test\n");
    printf("========================================\n");
    printf("\n");

    // Show initial heap state
    printf("Initial heap state:\n");
    printf("  Used:      %u bytes\n", heap_used());
    printf("  Available: %u bytes\n", heap_available());
    printf("\n");

    // Test 1: Simple malloc
    printf("Test 1: malloc(64)\n");
    buf1 = malloc(64);
    if (buf1) {
        printf("  [PASS] Allocated 64 bytes at 0x%x\n", (unsigned int)buf1);
        strcpy(buf1, "Hello from heap!");
        printf("  String: \"%s\"\n", buf1);
    } else {
        printf("  [FAIL] malloc returned NULL\n");
    }
    printf("  Heap used: %u bytes\n", heap_used());
    printf("\n");

    // Test 2: Multiple allocations
    printf("Test 2: Multiple allocations\n");
    buf2 = malloc(128);
    buf3 = malloc(256);
    if (buf2 && buf3) {
        printf("  [PASS] Allocated 128 + 256 bytes\n");
        printf("  buf2 at 0x%x\n", (unsigned int)buf2);
        printf("  buf3 at 0x%x\n", (unsigned int)buf3);
    } else {
        printf("  [FAIL] Allocation failed\n");
    }
    printf("  Heap used: %u bytes\n", heap_used());
    printf("\n");

    // Test 3: Array allocation
    printf("Test 3: Allocate integer array\n");
    nums = (int *)malloc(10 * sizeof(int));
    if (nums) {
        printf("  [PASS] Allocated array for 10 ints\n");
        for (i = 0; i < 10; i++) {
            nums[i] = i * i;
        }
        printf("  Values: ");
        for (i = 0; i < 10; i++) {
            printf("%d ", nums[i]);
        }
        printf("\n");
    } else {
        printf("  [FAIL] Array allocation failed\n");
    }
    printf("  Heap used: %u bytes\n", heap_used());
    printf("\n");

    // Test 4: calloc (zero-initialized)
    printf("Test 4: calloc(20, 1)\n");
    buf1 = (char *)calloc(20, 1);
    if (buf1) {
        int all_zero = 1;
        for (i = 0; i < 20; i++) {
            if (buf1[i] != 0) {
                all_zero = 0;
                break;
            }
        }
        if (all_zero) {
            printf("  [PASS] Memory is zero-initialized\n");
        } else {
            printf("  [FAIL] Memory not zeroed\n");
        }
    } else {
        printf("  [FAIL] calloc failed\n");
    }
    printf("  Heap used: %u bytes\n", heap_used());
    printf("\n");

    // Test 5: realloc
    printf("Test 5: realloc\n");
    buf1 = malloc(32);
    if (buf1) {
        strcpy(buf1, "Original");
        printf("  Original: \"%s\" at 0x%x\n", buf1, (unsigned int)buf1);

        buf2 = realloc(buf1, 64);
        if (buf2) {
            printf("  Reallocated to 0x%x\n", (unsigned int)buf2);
            printf("  Content preserved: \"%s\"\n", buf2);
        } else {
            printf("  [FAIL] realloc failed\n");
        }
    }
    printf("  Heap used: %u bytes\n", heap_used());
    printf("\n");

    // Test 6: Large allocation
    printf("Test 6: Large allocation (4KB)\n");
    buf1 = malloc(4096);
    if (buf1) {
        printf("  [PASS] Allocated 4KB at 0x%x\n", (unsigned int)buf1);
        memset(buf1, 'A', 4096);
        printf("  Filled with 'A'\n");
    } else {
        printf("  [FAIL] Large allocation failed\n");
    }
    printf("  Heap used: %u bytes\n", heap_used());
    printf("\n");

    // Test 7: Allocation until failure
    printf("Test 7: Allocate until failure\n");
    i = 0;
    while (1) {
        buf1 = malloc(1024);
        if (!buf1) break;
        i++;
    }
    printf("  Allocated %d blocks of 1KB\n", i);
    printf("  Heap used: %u bytes\n", heap_used());
    printf("  Heap available: %u bytes\n", heap_available());
    printf("\n");

    // Final heap state
    printf("Final heap state:\n");
    printf("  Used:      %u bytes\n", heap_used());
    printf("  Available: %u bytes\n", heap_available());
    printf("\n");

    printf("All memory tests completed!\n");
    printf("\n");

    return 0;
}
