# JX Operating System - Toolchain Configuration
# ==============================================
# Edit this file to configure paths for your development environment.
# This file is included by the main Makefile.

# ----------------------------------------------
# z80pack Installation Path
# ----------------------------------------------
# Path to the z80pack installation directory
Z80PACK_DIR = /Users/mreppot/src/z80pack

# ----------------------------------------------
# Assembler Configuration
# ----------------------------------------------
# Path to the z80asm assembler
Z80ASM = $(Z80PACK_DIR)/z80asm/z80asm

# Assembler flags for 8080 mode
# -8     : 8080 mode (reject Z80-only instructions)
# -l     : Generate listing file
# -T     : Omit symbol table from listing
# -sn    : Output symbol table sorted numerically
# -p0    : Fill unused memory with 0x00
ASM_FLAGS_COMMON = -8 -l -T -sn -p0

# Output format flags
# -fb    : Output flat binary format (no load address)
# -fh    : Output Intel HEX format (includes load address)
ASM_FLAGS_BIN = $(ASM_FLAGS_COMMON) -fb
ASM_FLAGS_HEX = $(ASM_FLAGS_COMMON) -fh

# Default format for builds
ASM_FLAGS = $(ASM_FLAGS_HEX)

# ----------------------------------------------
# Simulator Configuration
# ----------------------------------------------
# Path to the cpmsim simulator
SIMULATOR = $(Z80PACK_DIR)/cpmsim/cpmsim

# Simulator flags
# -8     : 8080 mode
# -m 00  : Initialize memory to 0x00
SIM_FLAGS = -8 -m 00

# Path to disk images for the simulator
DISK_PATH = $(Z80PACK_DIR)/cpmsim/disks

# ----------------------------------------------
# Memory Configuration
# ----------------------------------------------
# Target memory size in KB (32, 48, or 64)
# This affects where the OS components are assembled
MEM_SIZE = 64

# ----------------------------------------------
# Build Directories
# ----------------------------------------------
SRC_DIR = src
BUILD_DIR = build
BIOS_DIR = $(SRC_DIR)/bios
BDOS_DIR = $(SRC_DIR)/bdos
CCP_DIR = $(SRC_DIR)/ccp
TEST_DIR = $(SRC_DIR)/test

# ----------------------------------------------
# Output Files
# ----------------------------------------------
# Final system image
SYSTEM_IMAGE = $(BUILD_DIR)/jx.bin

# Component binaries
BIOS_BIN = $(BUILD_DIR)/bios.bin
BDOS_BIN = $(BUILD_DIR)/bdos.bin
CCP_BIN = $(BUILD_DIR)/ccp.bin
