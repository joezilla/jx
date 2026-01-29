#ifndef _STDLIB_H
#define _STDLIB_H

#include <stddef.h>
#include <stdint.h>

// Memory allocation
void *malloc(size_t size);
void free(void *ptr);
void *realloc(void *ptr, size_t size);
void *calloc(size_t nmemb, size_t size);

// Heap initialization (called from crt0)
void heap_init(void);

// Heap statistics (JX extensions)
size_t heap_used(void);
size_t heap_available(void);

// String conversion
int atoi(const char *str);
char *itoa(int value, char *str, int base);
char *utoa(uint16_t value, char *str, int base);

#endif // _STDLIB_H
