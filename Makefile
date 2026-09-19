# Native Linux tools; override OSS_CAD_DIR if installed elsewhere.
.DEFAULT_GOAL := core
OSS_CAD_DIR ?= $(HOME)/oss-cad-suite
export PATH := $(OSS_CAD_DIR)/bin:$(PATH)
PYTHON ?= /usr/bin/python3
RISCV_ARCH ?= rv32i_zicsr
RTL := rtl/core/*.sv rtl/pipeline/*.sv rtl/memory/*.sv rtl/peripherals/*.sv rtl/soc/*.sv
BUILD := build
LOG_DIR := $(BUILD)/logs
WAVE_DIR := $(BUILD)/waves
PROGRAM ?= programs/gpio_demo.S
SIM_DIR := $(BUILD)/sim
FPGA_DIR := fpga/tangnano9k
FPGA_BUILD := $(BUILD)/fpga
PROGRAM_BUILD := $(BUILD)/programs
TIMER_TICKS ?= 13500000
PROGRAM_ELF := $(PROGRAM_BUILD)/$(notdir $(PROGRAM:.S=.elf))
PROGRAM_BIN := $(PROGRAM_BUILD)/$(notdir $(PROGRAM:.S=.bin))
PROGRAM_HEX := $(PROGRAM_BUILD)/program.hex
UART_PORT ?= /dev/ttyUSB1
UART_BAUD ?= 115200
UART_SECONDS ?= 0
TEST_TIMEOUT ?= 30s
TEST_TIMER_TICKS ?= 8
TEST ?= raw_hazard

# Small tests remain individually runnable; groups explain their purpose.
STAGE_TESTS := if_stage id_stage ex_wb pipeline_flow
ISA_TESTS := arithmetic_regression branch_regression branch branch_not_taken \
	jump jalr u_type memory subword_memory
HAZARD_TESTS := raw_hazard load_use_hazard load_use_stall load_use_store \
	load_use_branch load_use_jalr branch_forwarding jal_forwarding jalr_forwarding \
	branch_flush jal_flush jalr_flush hazard_demo
TRAP_TESTS := ecall_trap timer_interrupt
PERIPHERAL_TESTS := timer uart_rx
SOC_TESTS := soc_gpio soc_uart soc_uart_rx soc_uart_echo soc_timer timer_led_chaser soc_button soc_integration soc_timer_interrupt soc_flush
TESTS := $(STAGE_TESTS) $(ISA_TESTS) $(HAZARD_TESTS) $(TRAP_TESTS) $(PERIPHERAL_TESTS) $(SOC_TESTS)

# Assembly tests share program.hex, so keep builds and simulations sequential.
.NOTPARALLEL:
.PHONY: core test test-stages test-isa test-hazards test-traps test-peripherals test-soc lint fpga flash \
	flash-gpio flash-hazard flash-nested flash-uart flash-timer flash-button \
	flash-integration flash-interrupt uart-monitor uart-ports wave program clean help FORCE

core:
	@mkdir -p $(SIM_DIR)
	iverilog -g2012 -s rv32i_pipelined_core -o $(SIM_DIR)/pipeline_sim $(RTL)

# Only these tests need an assembled program. Each uses the common recipe below.
test-hazard_demo: TEST_PROGRAM = programs/hazard_demo.S
test-ecall_trap: TEST_PROGRAM = programs/ecall_trap_demo.S
test-timer_interrupt: TEST_PROGRAM = programs/interrupt_trap_demo.S
test-soc_gpio: TEST_PROGRAM = programs/gpio_demo.S
test-soc_uart: TEST_PROGRAM = programs/uart_putc_demo.S
test-soc_uart_rx: TEST_PROGRAM = programs/uart_rx_gpio_demo.S
test-soc_uart_echo: TEST_PROGRAM = programs/uart_echo_demo.S
test-soc_timer: TEST_PROGRAM = programs/timer_demo.S
test-timer_led_chaser: TEST_PROGRAM = programs/timer_led_chaser.S
test-soc_button: TEST_PROGRAM = programs/button_demo.S
test-soc_integration: TEST_PROGRAM = programs/soc_integration_demo.S
test-soc_timer_interrupt: TEST_PROGRAM = programs/timer_interrupt_demo.S
test-soc_timer_interrupt: TEST_TIMER_TICKS = 40

test-%: tb/%_tb.sv
	@mkdir -p $(SIM_DIR) $(LOG_DIR) $(WAVE_DIR)
	@echo "==> $*_tb"
	@: > $(LOG_DIR)/$*_tb.log
	@if [ -n "$(TEST_PROGRAM)" ]; then \
		$(MAKE) PROGRAM=$(TEST_PROGRAM) TIMER_TICKS=$(TEST_TIMER_TICKS) program >> $(LOG_DIR)/$*_tb.log 2>&1 || { cat $(LOG_DIR)/$*_tb.log; exit 1; }; \
	fi
	@iverilog -g2012 -s $*_tb -o $(SIM_DIR)/$*_tb_sim $(RTL) $< >> $(LOG_DIR)/$*_tb.log 2>&1 || { cat $(LOG_DIR)/$*_tb.log; exit 1; }
	@timeout $(TEST_TIMEOUT) vvp $(SIM_DIR)/$*_tb_sim >> $(LOG_DIR)/$*_tb.log 2>&1 || { cat $(LOG_DIR)/$*_tb.log; echo "FAIL: $*_tb (simulation error or timeout)"; exit 1; }
	@if grep -Eq 'FAIL|ERROR:|FATAL:' $(LOG_DIR)/$*_tb.log; then cat $(LOG_DIR)/$*_tb.log; exit 1; fi
	@grep 'PASS' $(LOG_DIR)/$*_tb.log || { cat $(LOG_DIR)/$*_tb.log; echo "FAIL: no PASS result from $*_tb"; exit 1; }

test-stages: TESTS = $(STAGE_TESTS)
test-isa: TESTS = $(ISA_TESTS)
test-hazards: TESTS = $(HAZARD_TESTS)
test-traps: TESTS = $(TRAP_TESTS)
test-peripherals: TESTS = $(PERIPHERAL_TESTS)
test-soc: TESTS = $(SOC_TESTS)

test test-stages test-isa test-hazards test-traps test-peripherals test-soc:
	@passed=0; failed=0; \
	for test_name in $(TESTS); do \
		if $(MAKE) --no-print-directory test-$$test_name; then \
			passed=$$((passed + 1)); \
		else \
			failed=$$((failed + 1)); \
		fi; \
	done; \
	echo "REGRESSION: PASS $$passed/$(words $(TESTS)), FAIL $$failed/$(words $(TESTS))"; \
	test $$failed -eq 0

lint:
	verilator --lint-only -Wall -Wno-fatal --top-module rv32i_pipelined_soc $(RTL)

wave: test-$(TEST)
	@test -f $(WAVE_DIR)/$(TEST).vcd || { echo "No waveform: add a dump to tb/$(TEST)_tb.sv first."; exit 1; }
	gtkwave $(WAVE_DIR)/$(TEST).vcd

# Assembly is selected explicitly on each invocation; no selection state file.
program: $(PROGRAM_HEX)

$(PROGRAM_ELF): FORCE $(PROGRAM)
	@mkdir -p $(PROGRAM_BUILD)
	riscv64-unknown-elf-gcc -march=$(RISCV_ARCH) -mabi=ilp32 -nostdlib -DTIMER_TICKS=$(TIMER_TICKS) -Ttext=0x0 -o $@ $(PROGRAM)

$(PROGRAM_BIN): $(PROGRAM_ELF)
	riscv64-unknown-elf-objcopy -O binary $< $@

$(PROGRAM_HEX): $(PROGRAM_BIN) scripts/bin_to_hex.py
	$(PYTHON) scripts/bin_to_hex.py $(PROGRAM_BIN) $@

$(FPGA_BUILD)/rv32i.json: $(wildcard $(RTL)) $(FPGA_DIR)/top.sv $(PROGRAM_HEX)
	@mkdir -p $(FPGA_BUILD)
	yosys -p "read_verilog -sv $(RTL) $(FPGA_DIR)/top.sv; synth_gowin -top top -json $@"

$(FPGA_BUILD)/rv32i_pnr.json: $(FPGA_BUILD)/rv32i.json $(FPGA_DIR)/tangnano9k.cst
	nextpnr-himbaechel --json $< --write $@ \
		--device GW1NR-LV9QN88PC6/I5 --freq 27 --seed 30 \
		--vopt family=GW1N-9C --vopt cst=$(FPGA_DIR)/tangnano9k.cst

$(FPGA_BUILD)/rv32i.fs: $(FPGA_BUILD)/rv32i_pnr.json
	gowin_pack -d GW1N-9C -o $@ $<

fpga: $(FPGA_BUILD)/rv32i.fs
	@echo "FPGA image ready: $< (program: $(PROGRAM))"

flash: fpga
	openFPGALoader -b tangnano9k $(FPGA_BUILD)/rv32i.fs

# Named FPGA demos keep program selection explicit without long commands.
flash-gpio:
	$(MAKE) flash PROGRAM=programs/gpio_demo.S

flash-hazard:
	$(MAKE) flash PROGRAM=programs/hazard_demo.S

flash-nested:
	$(MAKE) flash PROGRAM=programs/nested_func.S

flash-uart:
	$(MAKE) flash PROGRAM=programs/uart_putc_demo.S

flash-timer:
	$(MAKE) flash PROGRAM=programs/timer_led_chaser.S

flash-button:
	$(MAKE) flash PROGRAM=programs/button_demo.S

flash-integration:
	$(MAKE) flash PROGRAM=programs/soc_integration_demo.S

flash-interrupt:
	$(MAKE) flash PROGRAM=programs/timer_interrupt_demo.S

# Use system Python for the installed pyserial package.
uart-ports:
	$(PYTHON) -m serial.tools.list_ports -v

uart-monitor:
	$(PYTHON) scripts/uart_monitor.py --port $(UART_PORT) --baud $(UART_BAUD) --seconds $(UART_SECONDS)

clean:
	# All generated files live here; source directories are untouched.
	rm -rf build/

help:
	@echo "Run from the repository root:"
	@echo "  make lint                 Check RTL warnings/errors"
	@echo "  make test                 Run all testbenches"
	@echo "  make test-load_use_stall  Run one testbench"
	@echo "  make wave TEST=load_use_stall  Run a test and open its waveform"
	@echo "  make program PROGRAM=programs/example.S  Build software only"
	@echo "  make fpga PROGRAM=programs/example.S     Build FPGA image"
	@echo "  make flash PROGRAM=programs/example.S    Build and load SRAM"
	@echo "  make flash-integration    Run the polling-based board demo"
	@echo "  make flash-interrupt      Run the timer-interrupt LED demo"
	@echo "  make uart-monitor         Listen to UART (Ctrl+C closes)"
	@echo "  make uart-ports           List available serial ports"
	@echo "  make clean                Delete ALL build/ outputs, including FPGA images"
	@echo "Without TEST, wave selects raw_hazard. See USAGE.md for details."
	@echo "Without PROGRAM, program/fpga/flash select programs/gpio_demo.S."
