.DEFAULT_GOAL := all

.PHONY: all flash clean

all: rv32i.fs

RTL := $(wildcard ../../rtl/core/*.sv ../../rtl/pipeline/*.sv ../../rtl/memory/*.sv ../../rtl/soc/*.sv)
# The default validates the current RAM + MMIO GPIO SoC checkpoint.
PROGRAM ?= programs/gpio_demo.S
PROGRAM_STEM := $(basename $(notdir $(PROGRAM)))
PROGRAM_ELF := $(PROGRAM_STEM).elf
PROGRAM_BIN := $(PROGRAM_STEM).bin
PROGRAM_HEX := program.hex
PROGRAM_SELECTION := .selected-program

$(PROGRAM_ELF): $(PROGRAM)
	riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -Ttext=0x0 -o $@ $<

$(PROGRAM_BIN): $(PROGRAM_ELF)
	riscv64-unknown-elf-objcopy -O binary $< $@

$(PROGRAM_SELECTION): FORCE
	@printf '%s\n' '$(PROGRAM)' | cmp -s - $@ || printf '%s\n' '$(PROGRAM)' > $@

$(PROGRAM_HEX): $(PROGRAM_BIN) $(PROGRAM_SELECTION) bin_to_hex.py
	python3 bin_to_hex.py $(PROGRAM_BIN) $@

rv32i.json: $(RTL) top.sv $(PROGRAM_HEX)
	yosys -p "read_verilog -sv $(RTL) top.sv; synth_gowin -top top -json rv32i.json"

rv32i_pnr.json: rv32i.json tangnano9k.cst
	nextpnr-himbaechel \
		--json rv32i.json \
		--write rv32i_pnr.json \
		--device GW1NR-LV9QN88PC6/I5 \
		--freq 27 \
		--seed 30 \
		--vopt family=GW1N-9C \
		--vopt cst=tangnano9k.cst

rv32i.fs: rv32i_pnr.json
	gowin_pack -d GW1N-9C -o rv32i.fs rv32i_pnr.json

.PHONY: flash FORCE

flash: rv32i.fs
	openFPGALoader -b tangnano9k rv32i.fs

clean:
	rm -f *.elf *.bin $(PROGRAM_HEX) $(PROGRAM_SELECTION) \
	      rv32i.json rv32i_pnr.json rv32i.fs
