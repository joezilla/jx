#include <stdio.h>
#include <string.h>
#include "../clib/bdos/bdos.h"

#define PROMPT "JX> "
#define CMD_MAX 128

// Forward declarations
void cmd_help(void);
void cmd_ver(void);
void cmd_mem(void);
void cmd_cls(void);
int load_program(char *name, char *args);
char *read_line(char *buf, int max_len);

int main(void) {
    char cmdline[CMD_MAX];
    char *cmd;
    char *arg;

    // Display banner
    printf("\n");
    printf("========================================\n");
    printf("  JX Operating System\n");
    printf("  Console Command Processor v1.0\n");
    printf("========================================\n");
    printf("\n");
    printf("Type 'help' for available commands\n");
    printf("\n");

    // Main command loop
    while (1) {
        // Display prompt
        printf(PROMPT);

        // Read command line
        if (!read_line(cmdline, CMD_MAX)) {
            continue;
        }

        printf("\n");  // Newline after input

        // Skip empty lines
        if (cmdline[0] == '\0') {
            continue;
        }

        // Parse command (first word)
        cmd = strtok(cmdline, " \t");
        if (!cmd) {
            continue;
        }

        // Get optional argument (rest of line)
        arg = strtok(NULL, "");

        // Built-in commands
        if (strcmp(cmd, "help") == 0) {
            cmd_help();
        } else if (strcmp(cmd, "?") == 0) {
            cmd_help();
        } else if (strcmp(cmd, "ver") == 0 || strcmp(cmd, "version") == 0) {
            cmd_ver();
        } else if (strcmp(cmd, "mem") == 0 || strcmp(cmd, "memory") == 0) {
            cmd_mem();
        } else if (strcmp(cmd, "cls") == 0 || strcmp(cmd, "clear") == 0) {
            cmd_cls();
        } else if (strcmp(cmd, "exit") == 0 || strcmp(cmd, "quit") == 0) {
            printf("Exiting JX...\n");
            bdos(BDOS_RESET, 0);  // Warm boot
            // Should not return
            break;
        } else {
            // Try to load and run as external program
            if (!load_program(cmd, arg)) {
                printf("Unknown command: %s\n", cmd);
                printf("Type 'help' for available commands\n");
            }
        }

        printf("\n");
    }

    return 0;
}

// Display help
void cmd_help(void) {
    printf("Available commands:\n");
    printf("  help, ?       Show this help message\n");
    printf("  ver, version  Show system version\n");
    printf("  mem, memory   Show memory information\n");
    printf("  cls, clear    Clear screen\n");
    printf("  exit, quit    Exit to system\n");
    printf("\n");
    printf("Built-in commands are case-sensitive.\n");
}

// Display version information
void cmd_ver(void) {
    uint16_t ver;

    printf("JX Operating System\n");
    printf("  CCP Version:  1.0\n");

    // Get BDOS version
    ver = bdos(BDOS_GETVER, 0);
    if (ver != 0) {
        printf("  BDOS Version: %u.%u\n", (ver >> 8) & 0xFF, ver & 0xFF);
    }

    printf("  Architecture: Intel 8080\n");
    printf("  Compiler:     SDCC 4.x\n");
}

// Display memory information
void cmd_mem(void) {
    uint16_t tpa_top;
    uint16_t mem_size;
    uint16_t tpa_size;

    // Get memory info from BDOS
    tpa_top = bdos_gettpa();
    mem_size = bdos_getmem();

    // Calculate TPA size
    tpa_size = tpa_top - 0x0100;

    printf("Memory Layout:\n");
    printf("  Total Memory:  %u KB\n", mem_size);
    printf("\n");
    printf("  TPA:   0x0100 - 0x%04X  (%u bytes, %u KB)\n",
           tpa_top, tpa_size, tpa_size / 1024);
    printf("  BDOS:  0x%04X - 0x%04X\n",
           tpa_top + 0x100, tpa_top + 0x8FF);
    printf("  BIOS:  0x%04X - 0xFFFF\n",
           tpa_top + 0x900);
    printf("\n");

    // Show heap info if available
    extern size_t heap_used(void);
    extern size_t heap_available(void);

    printf("Heap Status:\n");
    printf("  Used:      %u bytes\n", heap_used());
    printf("  Available: %u bytes\n", heap_available());
}

// Clear screen
void cmd_cls(void) {
    // ANSI escape sequence for clear screen
    printf("\033[2J\033[H");
}

// Load and execute external program
// TODO: Implement when disk I/O is available
int load_program(char *name, char *args) {
    // Stub for now
    (void)name;
    (void)args;
    return 0;  // Program not found
}

// Read a line from console
char *read_line(char *buf, int max_len) {
    int pos = 0;
    int c;

    while (pos < max_len - 1) {
        c = getchar();

        // Handle line ending
        if (c == '\n' || c == '\r') {
            buf[pos] = '\0';
            return buf;
        }

        // Handle backspace
        if (c == '\b' || c == 0x7F) {
            if (pos > 0) {
                pos--;
                putchar('\b');
                putchar(' ');
                putchar('\b');
            }
            continue;
        }

        // Store and echo character
        buf[pos++] = (char)c;
        putchar(c);
    }

    buf[pos] = '\0';
    return buf;
}
