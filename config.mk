# JX Monitor - Toolchain Configuration
# ======================================
# Edit this file to configure paths and hardware options.

# ----------------------------------------------
# z80pack Installation Path
# ----------------------------------------------
Z80PACK_DIR = ../z80pack

# ----------------------------------------------
# Assembler Configuration
# ----------------------------------------------
Z80ASM = $(Z80PACK_DIR)/z80asm/z80asm

# Assembler flags for 8080 mode
ASM_FLAGS_COMMON = -8 -e32 -l -T -sn -p0
ASM_FLAGS_BIN = $(ASM_FLAGS_COMMON) -fb
ASM_FLAGS_HEX = $(ASM_FLAGS_COMMON) -fh

# ----------------------------------------------
# Simulator Configuration
# ----------------------------------------------
SIMULATOR = $(Z80PACK_DIR)/cpmsim/cpmsim
SIM_FLAGS = -8 -m 00

# ----------------------------------------------
# Serial Configuration
# ----------------------------------------------
#
# ###################################################
# cpmsim (simulator):
#   SIO_DATA=01H  SIO_STATUS=00H  SIO_RX_MASK=0FFH  SIO_TX_MASK=0
#   Status port returns FFH (ready) or 00H (not ready).
#   No TX busy-wait needed.
#
#
# SIO_NAME    = CPMSIM
# SIO_DATA    = 01H
# SIO_STATUS  = 00H
# SIO_RX_MASK = 0FFH
# SIO_TX_MASK = 0
# SIO_8251   = 0

# SIO Channel B (disabled for simulator)
# SIO2_DATA    = 0
# SIO2_STATUS  = 0
# SIO2_RX_MASK = 0
#
# ###################################################
# IMSAI SIO (8251 USART, real hardware):
#   SIO_DATA=012H  SIO_STATUS=013H  SIO_RX_MASK=02H  SIO_TX_MASK=01H
#   Bit 1 = RX ready, Bit 0 = TX ready.
#
# SIO_NAME    = IMSAI SIO2
# SIO_DATA    = 12H
# SIO_STATUS  = 13H
# SIO_RX_MASK = 02H
# SIO_TX_MASK = 01H
# SIO_8251   = 1

# SIO Channel B (auxiliary serial port)
# SIO2_DATA    = 14H
# SIO2_STATUS  = 15H
# SIO2_RX_MASK = 02H
# 
#
# ###################################################
# ALTAIR 88-2SIO (6850 ACIA)
# Status: bit 0 = RX ready (RDRF), bit 1 = TX ready (TDRE)
# Requires 6850 master reset + mode init at boot.
# Note that the RX/TX masks are exactly opposite to the Imsai SIO.
#
SIO_NAME    = Altair 88-2SIO
SIO_DATA    = 011H
SIO_STATUS  = 010H
SIO_RX_MASK = 01H
SIO_TX_MASK = 02H
SIO_8251   = 0
SIO_6850   = 1

# SIO Channel B (disabled for simulator)
SIO2_DATA    = 013H
SIO2_STATUS  = 012H
SIO2_RX_MASK = 01H
SIO2_TX_MASK = 02H

# ----------------------------------------------
# Optional Modules
# ----------------------------------------------
ENABLE_TERM = 0

# BASIC: 0=none, 1=standalone boot, 2=build loadable hex
ENABLE_BASIC = 1

# ----------------------------------------------
# Version
# ----------------------------------------------
VER_MAJOR = 0
VER_MINOR = 6

# ----------------------------------------------
# Memory Configuration
# ----------------------------------------------
MEM_SIZE = 48

# Override BIOS_BASE to place monitor at a specific address.
# Leave blank to auto-derive from MEM_SIZE (top of RAM).
# Set to 0 for a flat binary loaded at address 0000H.
BIOS_BASE = 0

# Override STACK_TOP to place the stack at a specific address.
# Leave blank to auto-compute:
#   BIOS_BASE > 0: stack just below monitor (= BIOS_BASE)
#   BIOS_BASE = 0: stack at top of RAM (= MEMTOP)
# Note: auto-compute with MEM_SIZE=64 gives STACK_TOP=0000H (wraps to
# FFFFH), which is above physical RAM on a ~60KB system. Set explicitly
# to just below the VDM-1 framebuffer.
STACK_TOP = 0CC00H

# ----------------------------------------------
# Video Configuration
# ----------------------------------------------
# Processor Technology VDM-1
# 64 columns x 16 rows at C000H
# Set VIDEO_BASE=0 to disable video support
VIDEO_BASE = 0CC00H
VIDEO_CTRL = 0C8H
VIDEO_COLS = 64
VIDEO_ROWS = 16

# ----------------------------------------------
# Build Directories
# ----------------------------------------------
SRC_DIR = src
BUILD_DIR = build
BIOS_DIR = $(SRC_DIR)/bios

# ----------------------------------------------
# Output Files
# ----------------------------------------------
SYSTEM_BIN = $(BUILD_DIR)/jx.bin
SYSTEM_HEX = $(BUILD_DIR)/jx.hex
