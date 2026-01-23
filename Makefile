# JX Operating System - Main Makefile
# ====================================

# Include configuration
include config.mk

# ----------------------------------------------
# Calculated Addresses Based on Memory Size
# ----------------------------------------------
# These are passed to the assembler as defines
ifeq ($(MEM_SIZE),32)
    MEMTOP    = 08000H
    BIOS_BASE = 07D00H
    BDOS_BASE = 07500H
    TPA_TOP   = 07400H
else ifeq ($(MEM_SIZE),48)
    MEMTOP    = 0C000H
    BIOS_BASE = 0BD00H
    BDOS_BASE = 0B500H
    TPA_TOP   = 0B400H
else ifeq ($(MEM_SIZE),64)
    MEMTOP    = 00000H
    BIOS_BASE = 0FD00H
    BDOS_BASE = 0F500H
    TPA_TOP   = 0F400H
else
    $(error Unsupported MEM_SIZE: $(MEM_SIZE). Use 32, 48, or 64)
endif

# Memory defines passed to assembler
MEM_DEFINES = -dMEMTOP=$(MEMTOP) -dBIOS_BASE=$(BIOS_BASE) \
              -dBDOS_BASE=$(BDOS_BASE) -dTPA_TOP=$(TPA_TOP) \
              -dMEM_SIZE=$(MEM_SIZE)

# ----------------------------------------------
# File Discovery
# ----------------------------------------------
# Find all assembly source files
BIOS_SRCS = $(wildcard $(BIOS_DIR)/*.asm)
BDOS_SRCS = $(wildcard $(BDOS_DIR)/*.asm)
CCP_SRCS  = $(wildcard $(CCP_DIR)/*.asm)
TEST_SRCS = $(wildcard $(TEST_DIR)/*.asm)

# Generate output file names
TEST_BINS = $(patsubst $(TEST_DIR)/%.asm,$(BUILD_DIR)/test/%.bin,$(TEST_SRCS))
TEST_HEXS = $(patsubst $(TEST_DIR)/%.asm,$(BUILD_DIR)/test/%.hex,$(TEST_SRCS))
TEST_LSTS = $(patsubst $(TEST_DIR)/%.asm,$(BUILD_DIR)/test/%.lis,$(TEST_SRCS))

# ----------------------------------------------
# Phony Targets
# ----------------------------------------------
.PHONY: all clean distclean dirs test run run-test help check-tools

# ----------------------------------------------
# Default Target
# ----------------------------------------------
all: dirs check-tools $(SYSTEM_IMAGE)
	@echo "Build complete: $(SYSTEM_IMAGE)"
	@echo "Memory configuration: $(MEM_SIZE)KB"
	@echo "  BIOS at: $(BIOS_BASE)"
	@echo "  BDOS at: $(BDOS_BASE)"
	@echo "  TPA top: $(TPA_TOP)"

# ----------------------------------------------
# Help
# ----------------------------------------------
help:
	@echo "JX Operating System Build System"
	@echo "================================="
	@echo ""
	@echo "Targets:"
	@echo "  all          - Build the complete system (default)"
	@echo "  test         - Build all test programs"
	@echo "  run          - Run the system in the simulator"
	@echo "  run-test     - Run a test program (use TEST=name)"
	@echo "  clean        - Remove build artifacts"
	@echo "  distclean    - Remove build directory entirely"
	@echo "  check-tools  - Verify toolchain is available"
	@echo "  help         - Show this message"
	@echo ""
	@echo "Configuration:"
	@echo "  MEM_SIZE=N   - Set memory size (32, 48, 64). Default: 64"
	@echo ""
	@echo "Examples:"
	@echo "  make                      - Build for 64KB"
	@echo "  make MEM_SIZE=32          - Build for 32KB"
	@echo "  make test                 - Build test programs"
	@echo "  make run-test TEST=hello  - Run hello.asm test"
	@echo ""
	@echo "Configuration file: config.mk"

# ----------------------------------------------
# Tool Verification
# ----------------------------------------------
check-tools:
	@if [ ! -x "$(Z80ASM)" ]; then \
		echo "ERROR: Assembler not found at $(Z80ASM)"; \
		echo "Please check Z80PACK_DIR in config.mk"; \
		exit 1; \
	fi
	@if [ ! -x "$(SIMULATOR)" ]; then \
		echo "WARNING: Simulator not found at $(SIMULATOR)"; \
		echo "You can still build, but 'make run' will not work"; \
	fi

# ----------------------------------------------
# Directory Creation
# ----------------------------------------------
dirs:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/test

# ----------------------------------------------
# Assembly Rules
# ----------------------------------------------
# Generic rule for assembling .asm to .bin
# The assembler outputs files in the source directory, so we move them

# Build individual component
$(BUILD_DIR)/%.bin: $(SRC_DIR)/%.asm | dirs
	@echo "ASM  $<"
	@$(Z80ASM) $(ASM_FLAGS) $(MEM_DEFINES) -o$@ $<

# Build test programs (loaded at TPA = 0x0100)
# Generate both HEX (with load address) and BIN (raw) formats
$(BUILD_DIR)/test/%.hex: $(TEST_DIR)/%.asm | dirs
	@echo "ASM  $< -> $@ (Intel HEX)"
	@$(Z80ASM) $(ASM_FLAGS_HEX) -dTPA_BASE=0100H $(MEM_DEFINES) -o$@ $<

$(BUILD_DIR)/test/%.bin: $(TEST_DIR)/%.asm | dirs
	@echo "ASM  $< -> $@ (raw binary)"
	@$(Z80ASM) $(ASM_FLAGS_BIN) -dTPA_BASE=0100H $(MEM_DEFINES) -o$@ $<

# ----------------------------------------------
# System Image
# ----------------------------------------------
# For now, this is a placeholder that concatenates components
# A proper system builder tool will be needed later
$(SYSTEM_IMAGE): $(BIOS_BIN) $(BDOS_BIN) | dirs
	@echo "BUILD $(SYSTEM_IMAGE)"
	@if [ -f "$(BIOS_BIN)" ] && [ -f "$(BDOS_BIN)" ]; then \
		cat $(BDOS_BIN) $(BIOS_BIN) > $(SYSTEM_IMAGE); \
	elif [ -f "$(BIOS_BIN)" ]; then \
		cp $(BIOS_BIN) $(SYSTEM_IMAGE); \
	else \
		echo "No system components built yet"; \
		touch $(SYSTEM_IMAGE); \
	fi

# ----------------------------------------------
# Component Targets
# ----------------------------------------------
# BIOS targets (explicit rules due to subdirectory structure)
$(BUILD_DIR)/bios.bin: $(BIOS_DIR)/bios.asm | dirs
	@echo "ASM  $< -> $@ (raw binary)"
	@$(Z80ASM) $(ASM_FLAGS_BIN) $(MEM_DEFINES) -o$@ $<

$(BUILD_DIR)/bios.hex: $(BIOS_DIR)/bios.asm | dirs
	@echo "ASM  $< -> $@ (Intel HEX)"
	@$(Z80ASM) $(ASM_FLAGS_HEX) $(MEM_DEFINES) -o$@ $<

bios: dirs check-tools $(BIOS_BIN)
	@echo "BIOS built: $(BIOS_BIN)"

bios-hex: dirs check-tools $(BUILD_DIR)/bios.hex
	@echo "BIOS built: $(BUILD_DIR)/bios.hex"

bdos: dirs check-tools $(BDOS_BIN)
	@echo "BDOS built: $(BDOS_BIN)"

ccp: dirs check-tools $(CCP_BIN)
	@echo "CCP built: $(CCP_BIN)"

# ----------------------------------------------
# Test Targets
# ----------------------------------------------
test: dirs check-tools $(TEST_HEXS) $(TEST_BINS)
	@echo "Test programs built in $(BUILD_DIR)/test/"
	@echo "  .hex files - Intel HEX format (use with simulator -x flag)"
	@echo "  .bin files - Raw binary format"

# Build a specific test (both formats)
test-%: dirs check-tools $(BUILD_DIR)/test/%.hex $(BUILD_DIR)/test/%.bin
	@echo "Built test: $*"
	@echo "  $(BUILD_DIR)/test/$*.hex (Intel HEX)"
	@echo "  $(BUILD_DIR)/test/$*.bin (raw binary)"

# ----------------------------------------------
# Run Targets
# ----------------------------------------------
run: all
	@echo "Starting simulator with $(SYSTEM_IMAGE)..."
	@$(SIMULATOR) $(SIM_FLAGS) -x $(SYSTEM_IMAGE)

# Run a specific test program
# Usage: make run-test TEST=hello
run-test: dirs
ifndef TEST
	@echo "Usage: make run-test TEST=<name>"
	@echo "Available tests:"
	@ls -1 $(TEST_DIR)/*.asm 2>/dev/null | xargs -I {} basename {} .asm | sed 's/^/  /'
	@exit 1
endif
	@if [ ! -f "$(BUILD_DIR)/test/$(TEST).bin" ]; then \
		$(MAKE) $(BUILD_DIR)/test/$(TEST).bin; \
	fi
	@echo "Running test: $(TEST)"
	@./scripts/run-test.sh $(TEST)

# ----------------------------------------------
# Clean Targets
# ----------------------------------------------
clean:
	rm -f $(BUILD_DIR)/*.bin $(BUILD_DIR)/*.hex $(BUILD_DIR)/*.lis
	rm -f $(BUILD_DIR)/test/*.bin $(BUILD_DIR)/test/*.hex $(BUILD_DIR)/test/*.lis
	rm -f $(SRC_DIR)/**/*.lis

distclean:
	rm -rf $(BUILD_DIR)

# ----------------------------------------------
# Debug Info
# ----------------------------------------------
info:
	@echo "Configuration:"
	@echo "  Z80PACK_DIR  = $(Z80PACK_DIR)"
	@echo "  Z80ASM       = $(Z80ASM)"
	@echo "  SIMULATOR    = $(SIMULATOR)"
	@echo "  MEM_SIZE     = $(MEM_SIZE)KB"
	@echo ""
	@echo "Memory Layout:"
	@echo "  MEMTOP       = $(MEMTOP)"
	@echo "  BIOS_BASE    = $(BIOS_BASE)"
	@echo "  BDOS_BASE    = $(BDOS_BASE)"
	@echo "  TPA_TOP      = $(TPA_TOP)"
	@echo ""
	@echo "Sources:"
	@echo "  BIOS: $(BIOS_SRCS)"
	@echo "  BDOS: $(BDOS_SRCS)"
	@echo "  CCP:  $(CCP_SRCS)"
	@echo "  TEST: $(TEST_SRCS)"
