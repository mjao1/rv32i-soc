# RV32I bare-metal: build tests/<name>.c -> ../programs/<name>.mem for $readmemh
#
#   make                    # default TEST=cpu_return
#   make TEST=cpu_return    # explicit
#   make test TEST=foo      # same (convenience target)
#
# Optional extra translation units (same directory paths):
#   make TEST=foo EXTRA_SRCS="tests/foo_helpers.c"
#
PREFIX ?= riscv64-unknown-elf-
CC := $(PREFIX)gcc
OBJCOPY := $(PREFIX)objcopy

TEST ?= cpu_return
PAD_WORDS ?= 1024
EXTRA_SRCS ?=

CFLAGS := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O2 -Wall
LDFLAGS := -T link.ld

BUILD := build
PROG_MEM := ../programs/$(TEST).mem

.PHONY: all test clean list help

all: $(PROG_MEM)

test: all

help:
	@echo "Targets:"
	@echo "  make [TEST=<name>]     Build tests/<name>.c -> ../programs/<name>.mem"
	@echo "  make list              Print available test names (tests/*.c)"
	@echo "  make clean             Remove build/ and ../programs/\$$(TEST).mem"
	@echo "Variables: TEST (default cpu_return), EXTRA_SRCS, PAD_WORDS, PREFIX"

list:
	@ls -1 tests/*.c 2>/dev/null | sed 's|tests/||;s|\.c$$||' || true

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/$(TEST).elf: crt0.S tests/$(TEST).c link.ld | $(BUILD)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ crt0.S tests/$(TEST).c $(EXTRA_SRCS)

$(BUILD)/$(TEST).bin: $(BUILD)/$(TEST).elf
	$(OBJCOPY) -O binary $< $@

$(PROG_MEM): $(BUILD)/$(TEST).bin bin2mem.py
	python3 bin2mem.py $< $@ $(PAD_WORDS)
	@if [ "$(TEST)" = "cpu_return" ]; then cp -f $@ ../programs/main.mem; fi

clean:
	rm -rf $(BUILD)
	rm -f $(PROG_MEM)
