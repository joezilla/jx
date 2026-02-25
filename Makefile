# JX Monitor - Makefile
# =====================

CONFIG ?= config.mk
include $(CONFIG)

# ----------------------------------------------
# Memory Layout
# ----------------------------------------------
# MEMTOP = top of physical RAM (wraps to 0 for 64KB).
# BIOS_BASE = ORG address for the monitor.
#
# Default: monitor at top of RAM (derived from MEM_SIZE).
# Override BIOS_BASE in config.mk for custom placement.
ifeq ($(MEM_SIZE),32)
    MEMTOP    = 08000H
    _DEF_BASE = 07400H
else ifeq ($(MEM_SIZE),48)
    MEMTOP    = 0C000H
    _DEF_BASE = 0B400H
else ifeq ($(MEM_SIZE),64)
    MEMTOP    = 00000H
    _DEF_BASE = 0F400H
else
    $(error Unsupported MEM_SIZE: $(MEM_SIZE). Use 32, 48, or 64)
endif

# Use explicit BIOS_BASE if set, otherwise derive from MEM_SIZE
ifeq ($(strip $(BIOS_BASE)),)
    BIOS_BASE = $(_DEF_BASE)
endif

# Stack location: below monitor (traditional) or top of RAM (load-at-zero)
ifeq ($(strip $(STACK_TOP)),)
    ifeq ($(BIOS_BASE),0)
        STACK_TOP = $(MEMTOP)
    else
        STACK_TOP = $(BIOS_BASE)
    endif
endif

# Assembler defines
MEM_DEFINES = -dBIOS_BASE=$(BIOS_BASE) -dMEM_SIZE=$(MEM_SIZE)
MEM_DEFINES += -dSTACK_TOP=$(STACK_TOP) -dMEMTOP=$(MEMTOP)
MEM_DEFINES += -dVER_MAJOR=$(VER_MAJOR) -dVER_MINOR=$(VER_MINOR)

# Serial defines
HW_DEFINES = -dSIO_DATA=$(SIO_DATA) -dSIO_STATUS=$(SIO_STATUS)
HW_DEFINES += -dSIO_RX_MASK=$(SIO_RX_MASK) -dSIO_TX_MASK=$(SIO_TX_MASK)
HW_DEFINES += -dSIO_8251=$(SIO_8251)
HW_DEFINES += -dSIO2_DATA=$(SIO2_DATA) -dSIO2_STATUS=$(SIO2_STATUS)
HW_DEFINES += -dSIO2_RX_MASK=$(SIO2_RX_MASK)

# Video defines (always pass VIDEO_BASE so IF/ENDIF works before INCLUDE)
HW_DEFINES += -dVIDEO_BASE=$(VIDEO_BASE)
ifneq ($(VIDEO_BASE),0)
    HW_DEFINES += -dVIDEO_CTRL=$(VIDEO_CTRL)
    HW_DEFINES += -dVIDEO_COLS=$(VIDEO_COLS)
    HW_DEFINES += -dVIDEO_ROWS=$(VIDEO_ROWS)
endif

# Optional module defines
MOD_DEFINES =
ifeq ($(ENABLE_TERM),1)
    MOD_DEFINES += -dENABLE_TERM=1
endif

ALL_DEFINES = $(MEM_DEFINES) $(HW_DEFINES) $(MOD_DEFINES)

# Source files
BIOS_SRCS = $(wildcard $(BIOS_DIR)/*.asm) \
            $(wildcard $(SRC_DIR)/lib/*.asm) \
            $(wildcard $(SRC_DIR)/*.asm) \
            $(wildcard $(SRC_DIR)/cmd/*.asm)

# ----------------------------------------------
# Targets
# ----------------------------------------------
.PHONY: all hex disk clean distclean run test help check-tools info dirs

all: dirs check-tools $(SYSTEM_BIN)
	@echo "Build complete: $(SYSTEM_BIN)"
	@echo "  Monitor at: $(BIOS_BASE)"
	@echo "  Stack at:   $(STACK_TOP)"
	@echo "  Memory:     $(MEM_SIZE)KB"
	@echo "  Serial:     data=$(SIO_DATA) status=$(SIO_STATUS) rx=$(SIO_RX_MASK) tx=$(SIO_TX_MASK)"
ifneq ($(VIDEO_BASE),0)
	@echo "  Video:      $(VIDEO_BASE) ($(VIDEO_COLS)x$(VIDEO_ROWS))"
endif
ifeq ($(ENABLE_TERM),1)
	@echo "  Modules:    term"
endif

hex: dirs check-tools $(SYSTEM_HEX)
	@echo "Build complete: $(SYSTEM_HEX)"
	@echo "  Monitor at: $(BIOS_BASE)"

help:
	@echo "JX Monitor Build System"
	@echo "========================"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build flat binary (default)"
	@echo "  hex        - Build Intel HEX (for cpmsim)"
	@echo "  disk       - Build hex and create boot disk image"
	@echo "  run        - Build hex and run in simulator"
	@echo "  clean      - Remove build artifacts"
	@echo "  distclean  - Remove build directory"
	@echo "  info       - Display configuration"
	@echo "  help       - Show this message"
	@echo ""
	@echo "Options:"
	@echo "  MEM_SIZE=N       - Memory: 32, 48, 64 (default: 64)"
	@echo "  BIOS_BASE=addr   - Monitor address (0=load at zero)"
	@echo "  STACK_TOP=addr   - Stack address (default: auto)"
	@echo "  VIDEO_BASE=addr  - Video address (0=disabled)"
	@echo ""
	@echo "Serial presets (override on command line):"
	@echo "  cpmsim (default): SIO_DATA=01H SIO_STATUS=00H SIO_RX_MASK=0FFH SIO_TX_MASK=0"
	@echo "  IMSAI SIO:        SIO_DATA=012H SIO_STATUS=013H SIO_RX_MASK=02H SIO_TX_MASK=01H"

check-tools:
	@if [ ! -x "$(Z80ASM)" ]; then \
		echo "ERROR: Assembler not found at $(Z80ASM)"; \
		echo "Check Z80PACK_DIR in config.mk"; \
		exit 1; \
	fi

dirs:
	@mkdir -p $(BUILD_DIR)

# Build flat binary
# Note: cd into BIOS_DIR so INCLUDE directives resolve relative to source
$(SYSTEM_BIN): $(BIOS_SRCS) | dirs
	@echo "ASM  bios.asm -> $@"
	@cd $(BIOS_DIR) && $(CURDIR)/$(Z80ASM) $(ASM_FLAGS_BIN) $(ALL_DEFINES) -o$(CURDIR)/$@ bios.asm

# Build Intel HEX (for cpmsim -x loading)
$(SYSTEM_HEX): $(BIOS_SRCS) | dirs
	@echo "ASM  bios.asm -> $@"
	@cd $(BIOS_DIR) && $(CURDIR)/$(Z80ASM) $(ASM_FLAGS_HEX) $(ALL_DEFINES) -o$(CURDIR)/$@ bios.asm

# Create boot disk image
disk: hex
	@echo "DISK $(SYSTEM_HEX) -> $(SYSTEM_DSK)"
	@node scripts/create-boot-disk.js --8inch -o $(SYSTEM_DSK) $(SYSTEM_HEX)

run: hex
	@echo "Starting JX Monitor..."
	@$(SIMULATOR) $(SIM_FLAGS) -x $(SYSTEM_HEX)

test:
	@./tests/run-tests.sh

clean:
	rm -f $(BUILD_DIR)/*.bin $(BUILD_DIR)/*.hex $(BUILD_DIR)/*.lis
	rm -f $(SYSTEM_DSK)
	rm -f $(SRC_DIR)/**/*.lis

distclean:
	rm -rf $(BUILD_DIR)

info:
	@echo "Configuration:"
	@echo "  Z80PACK_DIR = $(Z80PACK_DIR)"
	@echo "  Z80ASM      = $(Z80ASM)"
	@echo "  SIMULATOR   = $(SIMULATOR)"
	@echo ""
	@echo "Memory Layout ($(MEM_SIZE)KB):"
	@echo "  BIOS_BASE   = $(BIOS_BASE)"
	@echo "  STACK_TOP   = $(STACK_TOP)"
	@echo "  MEMTOP      = $(MEMTOP)"
	@echo ""
	@echo "Serial:"
	@echo "  Data port   = $(SIO_DATA)"
	@echo "  Status port = $(SIO_STATUS)"
	@echo "  RX mask     = $(SIO_RX_MASK)"
	@echo "  TX mask     = $(SIO_TX_MASK)"
	@echo ""
	@echo "Video:"
	@echo "  Video base  = $(VIDEO_BASE)"
ifneq ($(VIDEO_BASE),0)
	@echo "  Video size  = $(VIDEO_COLS)x$(VIDEO_ROWS)"
endif
	@echo ""
	@echo "Assembler defines: $(ALL_DEFINES)"
