.DEFAULT_GOAL := all

.PHONY: all flash clean

all: rv32i.fs

RTL := $(wildcard ../../rtl/core/*.sv ../../rtl/pipeline/*.sv ../../rtl/memory/*.sv)

program.elf: program.S
	riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -Ttext=0x0 -o program.elf program.S

program.bin: program.elf
	riscv64-unknown-elf-objcopy -O binary program.elf program.bin

program.hex: program.bin bin_to_hex.py
	python3 bin_to_hex.py program.bin program.hex

rv32i.json: $(RTL) top.sv program.hex
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

.PHONY: flash

flash: rv32i.fs
	openFPGALoader -b tangnano9k rv32i.fs

clean:
	rm -f program.elf program.bin program.hex \
	      rv32i.json rv32i_pnr.json rv32i.fs
