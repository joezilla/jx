#ifndef _STRING_H
#define _STRING_H

#include <stddef.h>

// String length
size_t strlen(const char *s);

// String copy
char *strcpy(char *dest, const char *src);
char *strncpy(char *dest, const char *src, size_t n);

// String compare
int strcmp(const char *s1, const char *s2);
int strncmp(const char *s1, const char *s2, size_t n);

// String concatenate
char *strcat(char *dest, const char *src);
char *strncat(char *dest, const char *src, size_t n);

// String search
char *strchr(const char *s, int c);
char *strrchr(const char *s, int c);

// String tokenization
char *strtok(char *str, const char *delim);

// Memory operations
void *memcpy(void *dest, const void *src, size_t n);
void *memmove(void *dest, const void *src, size_t n);
void *memset(void *s, int c, size_t n);
int memcmp(const void *s1, const void *s2, size_t n);

#endif // _STRING_H
