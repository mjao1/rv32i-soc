# RV32I bare-metal: build tests/<name>.c -> ../programs/<name>.mem for $readmemh
#
#   make                         # build every tests/*.c (same as `make all`)
#   make TEST=<name>             # build tests/<name>.c only
#   make TEST=soc_programs       # build every tests/soc_program_*.c
#
PREFIX ?= riscv64-unknown-elf-
CC := $(PREFIX)gcc
OBJCOPY := $(PREFIX)objcopy

TEST ?= cpu_smoke
PAD_WORDS ?= 1024

ALL_TESTS := $(patsubst tests/%.c,%,$(wildcard tests/*.c))
SOC_PROGRAMS := $(filter soc_program_%,$(ALL_TESTS))
ALL_MEMS := $(addprefix ../programs/,$(addsuffix .mem,$(ALL_TESTS)))
SOC_PROGRAM_MEMS := $(addprefix ../programs/,$(addsuffix .mem,$(SOC_PROGRAMS)))

CFLAGS := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O2 -Wall
LDFLAGS := -T link.ld

BUILD := build

# `make` with no TEST override => build everything; `make TEST=foo` => that one
ifeq ($(origin TEST),command line)
.DEFAULT_GOAL := single
else
.DEFAULT_GOAL := all
endif

.PHONY: all single soc_programs clean help list
.PRECIOUS: $(BUILD)/%.elf $(BUILD)/%.bin

all: $(ALL_MEMS)

ifeq ($(TEST),soc_programs)
single: soc_programs
else
single: ../programs/$(TEST).mem
endif

soc_programs: $(SOC_PROGRAM_MEMS)

help:
	@echo "Targets:"
	@echo "  make                       Build all tests/*.c"
	@echo "  make TEST=<name>           Build tests/<name>.c -> ../programs/<name>.mem"
	@echo "  make TEST=soc_programs     Build every tests/soc_program_*.c"
	@echo "  make list                  Print available test names (tests/*.c)"
	@echo "  make clean                 Remove build/ and ../programs/*.mem"

list:
	@ls -1 tests/*.c 2>/dev/null | sed 's|tests/||;s|\.c$$||' || true

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.elf: crt0.S tests/%.c link.ld | $(BUILD)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ crt0.S tests/$*.c

$(BUILD)/%.bin: $(BUILD)/%.elf
	$(OBJCOPY) -O binary $< $@

../programs/%.mem: $(BUILD)/%.bin bin2mem.py
	python3 bin2mem.py $< $@ $(PAD_WORDS)

clean:
	rm -rf $(BUILD)
	rm -f $(ALL_MEMS)
