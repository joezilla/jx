#ifndef _BDOS_H
#define _BDOS_H

#include <stdint.h>

// BDOS function numbers
#define BDOS_RESET      0x00    // System reset (warm boot)
#define BDOS_CONIN      0x01    // Console input
#define BDOS_CONOUT     0x02    // Console output
#define BDOS_READER     0x03    // Reader input
#define BDOS_PUNCH      0x04    // Punch output
#define BDOS_LIST       0x05    // List output
#define BDOS_RAWIO      0x06    // Direct console I/O
#define BDOS_GETIOB     0x07    // Get I/O byte
#define BDOS_SETIOB     0x08    // Set I/O byte
#define BDOS_PRINT      0x09    // Print string ($ terminated)
#define BDOS_READLN     0x0A    // Read console buffer
#define BDOS_CONST      0x0B    // Console status
#define BDOS_GETVER     0x0C    // Get version number
#define BDOS_DSKRESET   0x0D    // Reset disk system
#define BDOS_SELDSK     0x0E    // Select disk
#define BDOS_OPEN       0x0F    // Open file
#define BDOS_CLOSE      0x10    // Close file
#define BDOS_SFIRST     0x11    // Search for first
#define BDOS_SNEXT      0x12    // Search for next
#define BDOS_DELETE     0x13    // Delete file
#define BDOS_READ       0x14    // Read sequential
#define BDOS_WRITE      0x15    // Write sequential
#define BDOS_MAKE       0x16    // Make file
#define BDOS_RENAME     0x17    // Rename file
#define BDOS_LOGIVEC    0x18    // Return login vector
#define BDOS_CURDSK     0x19    // Return current disk
#define BDOS_SETDMA     0x1A    // Set DMA address
#define BDOS_GETTPA     0x31    // Get TPA top address (JX extension)
#define BDOS_GETMEM     0x32    // Get memory size (JX extension)

// BDOS call interface
// func: BDOS function number
// arg: 16-bit argument (meaning depends on function)
// Returns: 16-bit result (meaning depends on function)
uint16_t bdos(uint8_t func, uint16_t arg);

// Console I/O wrappers
uint8_t bdos_conin(void);
void bdos_conout(char c);
void bdos_print(const char *str);
uint8_t bdos_const(void);

// Memory info
uint16_t bdos_gettpa(void);
uint16_t bdos_getmem(void);

#endif // _BDOS_H
