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
dirs: dirs-clib
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
# System image with CCP, BDOS, and BIOS
# Layout: CCP (loaded at 0x0100) + BDOS + BIOS
$(SYSTEM_IMAGE): $(CCP_BIN) $(BDOS_BIN) $(BIOS_BIN) | dirs
	@echo "BUILD $(SYSTEM_IMAGE) with CCP"
	@cat $(CCP_BIN) $(BDOS_BIN) $(BIOS_BIN) > $(SYSTEM_IMAGE)
	@echo "  CCP:  $(CCP_BIN) ("`ls -lh $(CCP_BIN) | awk '{print $$5}'`")"
	@echo "  BDOS: $(BDOS_BIN)"
	@echo "  BIOS: $(BIOS_BIN)"

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

# BDOS targets (explicit rules due to subdirectory structure)
# Note: BDOS defines its own memory addresses internally
$(BUILD_DIR)/bdos.bin: $(BDOS_DIR)/bdos.asm | dirs
	@echo "ASM  $< -> $@ (raw binary)"
	@$(Z80ASM) $(ASM_FLAGS_BIN) -o$@ $<

$(BUILD_DIR)/bdos.hex: $(BDOS_DIR)/bdos.asm | dirs
	@echo "ASM  $< -> $@ (Intel HEX)"
	@$(Z80ASM) $(ASM_FLAGS_HEX) -o$@ $<

bdos: dirs check-tools $(BDOS_BIN)
	@echo "BDOS built: $(BDOS_BIN)"

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
# C Compilation Rules
# ----------------------------------------------
# Find C source files in clib
CLIB_C_SRCS = $(wildcard $(CLIB_DIR)/bdos/*.c) \
              $(wildcard $(CLIB_DIR)/stdio/*.c) \
              $(wildcard $(CLIB_DIR)/string/*.c) \
              $(wildcard $(CLIB_DIR)/stdlib/*.c)

# Generate .rel object file names
CLIB_OBJS = $(patsubst $(CLIB_DIR)/%.c,$(CLIB_BUILD)/%.rel,$(CLIB_C_SRCS))

# C library archive
LIBJX = $(BUILD_DIR)/libjx.lib

# crt0 object file
CRT0_REL = $(CLIB_BUILD)/crt0.rel

# Create clib subdirectories
dirs-clib:
	@mkdir -p $(CLIB_BUILD)/bdos $(CLIB_BUILD)/stdio $(CLIB_BUILD)/string $(CLIB_BUILD)/stdlib $(CLIB_BUILD)/crt0
	@mkdir -p $(BUILD_DIR)/examples
	@mkdir -p $(BUILD_DIR)/ccp

# Assemble crt0.s to crt0.rel
$(CRT0_REL): $(CLIB_DIR)/crt0/crt0.s | dirs-clib
	@echo "AS   $<"
	@$(SDCC_AS) -plosgff -o $@ $<

# Compile C source to .rel
$(CLIB_BUILD)/%.rel: $(CLIB_DIR)/%.c | dirs-clib
	@echo "CC   $<"
	@$(SDCC) $(SDCC_FLAGS) -I$(CLIB_DIR) -c -o $@ $<

# Build C library archive
$(LIBJX): $(CLIB_OBJS) | dirs-clib
	@echo "AR   $@"
	@rm -f $@
	@$(SDCC_AR) -rc $@ $(CLIB_OBJS)

# Compile C example programs
$(BUILD_DIR)/examples/%.rel: $(EXAMPLES_DIR)/%.c | dirs-clib
	@echo "CC   $<"
	@$(SDCC) $(SDCC_FLAGS) -I$(CLIB_DIR) -c -o $@ $<

# Link C program to .ihx
$(BUILD_DIR)/examples/%.ihx: $(BUILD_DIR)/examples/%.rel $(CRT0_REL) $(LIBJX) | dirs-clib
	@echo "LD   $@"
	@$(SDCC) $(SDCC_FLAGS) \
		--code-loc 0x0100 \
		--data-loc 0x8000 \
		--no-std-crt0 \
		-o $@ \
		$(CRT0_REL) \
		$(BUILD_DIR)/examples/$*.rel \
		$(LIBJX)

# Convert .ihx to .hex (Intel HEX format)
$(BUILD_DIR)/examples/%.hex: $(BUILD_DIR)/examples/%.ihx
	@echo "HEX  $@"
	@cp $< $@

# Convert .ihx to .bin (raw binary)
$(BUILD_DIR)/examples/%.bin: $(BUILD_DIR)/examples/%.ihx
	@echo "BIN  $@"
	@objcopy -I ihex -O binary $< $@

# Build all C examples
examples: dirs-clib $(LIBJX) $(CRT0_REL)
	@echo "C library and examples ready"
	@echo "To build an example: make $(BUILD_DIR)/examples/<name>.hex"

# Build and run a C example
# Usage: make run-example EXAMPLE=hello
run-example:
ifndef EXAMPLE
	@echo "Usage: make run-example EXAMPLE=<name>"
	@echo "Available examples:"
	@ls -1 $(EXAMPLES_DIR)/*.c 2>/dev/null | xargs -I {} basename {} .c | sed 's/^/  /' || echo "  (none yet)"
	@exit 1
endif
	@$(MAKE) $(BUILD_DIR)/examples/$(EXAMPLE).hex
	@echo "Running example: $(EXAMPLE)"
	@$(SIMULATOR) $(SIM_FLAGS) -x $(BUILD_DIR)/examples/$(EXAMPLE).hex

# ----------------------------------------------
# CCP Build Rules
# ----------------------------------------------
# Compile CCP source
$(BUILD_DIR)/ccp/ccp.rel: $(CCP_DIR)/ccp.c | dirs-clib
	@echo "CC   $<"
	@$(SDCC) $(SDCC_FLAGS) -I$(CLIB_DIR) -c -o $@ $<

# Link CCP to .ihx
$(BUILD_DIR)/ccp/ccp.ihx: $(BUILD_DIR)/ccp/ccp.rel $(CRT0_REL) $(LIBJX) | dirs-clib
	@echo "LD   $@"
	@$(SDCC) $(SDCC_FLAGS) \
		--code-loc 0x0100 \
		--data-loc 0x8000 \
		--no-std-crt0 \
		-o $@ \
		$(CRT0_REL) \
		$(BUILD_DIR)/ccp/ccp.rel \
		$(LIBJX)

# Convert CCP to .hex format
$(BUILD_DIR)/ccp/ccp.hex: $(BUILD_DIR)/ccp/ccp.ihx
	@echo "HEX  $@"
	@cp $< $@

# Convert CCP to .bin format
$(BUILD_DIR)/ccp/ccp.bin: $(BUILD_DIR)/ccp/ccp.ihx
	@echo "BIN  $@"
	@makebin -p $< $@

# Build CCP
ccp: dirs-clib $(BUILD_DIR)/ccp/ccp.hex $(BUILD_DIR)/ccp/ccp.bin
	@echo "CCP built: $(BUILD_DIR)/ccp/ccp.hex"

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
	rm -f $(CLIB_BUILD)/**/*.rel $(CLIB_BUILD)/**/*.asm $(CLIB_BUILD)/**/*.lst $(CLIB_BUILD)/**/*.sym
	rm -f $(BUILD_DIR)/examples/*.rel $(BUILD_DIR)/examples/*.ihx $(BUILD_DIR)/examples/*.hex $(BUILD_DIR)/examples/*.bin
	rm -f $(BUILD_DIR)/*.lib
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
