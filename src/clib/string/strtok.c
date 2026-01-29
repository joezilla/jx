#include "string.h"

// Static pointer for maintaining state between calls
static char *next_token = NULL;

// String tokenization
char *strtok(char *str, const char *delim) {
    char *token_start;

    // Use saved pointer if str is NULL
    if (str != NULL) {
        next_token = str;
    }

    // No more tokens
    if (next_token == NULL || *next_token == '\0') {
        return NULL;
    }

    // Skip leading delimiters
    while (*next_token && strchr(delim, *next_token)) {
        next_token++;
    }

    // No more tokens
    if (*next_token == '\0') {
        next_token = NULL;
        return NULL;
    }

    // Found start of token
    token_start = next_token;

    // Find end of token
    while (*next_token && !strchr(delim, *next_token)) {
        next_token++;
    }

    // Null-terminate token if not at end of string
    if (*next_token != '\0') {
        *next_token = '\0';
        next_token++;
    } else {
        next_token = NULL;
    }

    return token_start;
}
