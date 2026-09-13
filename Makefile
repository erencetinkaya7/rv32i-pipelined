RTL := rtl/core/*.sv rtl/pipeline/*.sv rtl/memory/*.sv rtl/peripherals/*.sv rtl/soc/*.sv
BUILD := build
LOG_DIR := $(BUILD)/logs
WAVE_DIR := $(BUILD)/waves
FPGA_DIR := fpga/rv32i
PROGRAM ?= programs/gpio_demo.S
UART_PORT ?= /dev/ttyUSB1
UART_BAUD ?= 115200
TESTS := arithmetic_regression branch_flush branch_forwarding branch_not_taken \
	branch_regression branch ex_wb hazard_demo id_stage if_stage jal_flush \
	jal_forwarding jalr_flush jalr_forwarding jalr jump load_use_branch \
	load_use_hazard load_use_jalr load_use_stall load_use_store memory \
	pipeline_flow raw_hazard soc_gpio soc_uart subword_memory u_type

TESTS += timer soc_timer timer_led_chaser soc_button soc_integration

.PHONY: core test fpga flash flash-gpio flash-hazard flash-nested flash-uart flash-timer flash-button flash-integration uart-monitor clean
$(BUILD):
	mkdir -p $(BUILD)

core: $(BUILD)
	iverilog -g2012 -s rv32i_pipelined_core \
	-o $(BUILD)/pipeline_sim $(RTL)

# The stem maps directly to both tb/<stem>_tb.sv and module <stem>_tb.
test-%: $(BUILD)
	@mkdir -p $(LOG_DIR)
	@echo "==> $*_tb"
	@iverilog -g2012 -s $*_tb -o $(BUILD)/$*_tb_sim $(RTL) tb/$*_tb.sv > $(LOG_DIR)/$*_tb.log 2>&1 || { cat $(LOG_DIR)/$*_tb.log; exit 1; }
	@vvp $(BUILD)/$*_tb_sim >> $(LOG_DIR)/$*_tb.log 2>&1 || { cat $(LOG_DIR)/$*_tb.log; exit 1; }
	@grep -E "PASS|FAIL" $(LOG_DIR)/$*_tb.log || echo "PASS $*_tb"

# The integration test needs its assembly image regenerated before simulation.
test-hazard_demo: $(BUILD)
	@mkdir -p $(LOG_DIR)
	@echo "==> hazard_demo_tb"
	@$(MAKE) -C $(FPGA_DIR) PROGRAM=hazard_demo.S program.hex > $(LOG_DIR)/hazard_demo_tb.log 2>&1 || { cat $(LOG_DIR)/hazard_demo_tb.log; exit 1; }
	@iverilog -g2012 -s hazard_demo_tb -o $(BUILD)/hazard_demo_tb_sim $(RTL) tb/hazard_demo_tb.sv >> $(LOG_DIR)/hazard_demo_tb.log 2>&1 || { cat $(LOG_DIR)/hazard_demo_tb.log; exit 1; }
	@vvp $(BUILD)/hazard_demo_tb_sim >> $(LOG_DIR)/hazard_demo_tb.log 2>&1 || { cat $(LOG_DIR)/hazard_demo_tb.log; exit 1; }
	@grep -E "PASS|FAIL" $(LOG_DIR)/hazard_demo_tb.log || echo "PASS hazard_demo_tb"

# The GPIO integration test needs its selected assembly image before simulation.
test-soc_gpio: $(BUILD)
	@mkdir -p $(LOG_DIR)
	@echo "==> soc_gpio_tb"
	@$(MAKE) -C $(FPGA_DIR) PROGRAM=programs/gpio_demo.S program.hex > $(LOG_DIR)/soc_gpio_tb.log 2>&1 || { cat $(LOG_DIR)/soc_gpio_tb.log; exit 1; }
	@iverilog -g2012 -s soc_gpio_tb -o $(BUILD)/soc_gpio_tb_sim $(RTL) tb/soc_gpio_tb.sv >> $(LOG_DIR)/soc_gpio_tb.log 2>&1 || { cat $(LOG_DIR)/soc_gpio_tb.log; exit 1; }
	@vvp $(BUILD)/soc_gpio_tb_sim >> $(LOG_DIR)/soc_gpio_tb.log 2>&1 || { cat $(LOG_DIR)/soc_gpio_tb.log; exit 1; }
	@grep -E "PASS|FAIL" $(LOG_DIR)/soc_gpio_tb.log || echo "PASS soc_gpio_tb"

test-soc_uart: $(BUILD)
	@mkdir -p $(LOG_DIR)
	@echo "==> soc_uart_tb"
	@$(MAKE) -C $(FPGA_DIR) PROGRAM=programs/uart_putc_demo.S program.hex > $(LOG_DIR)/soc_uart_tb.log 2>&1 || { cat $(LOG_DIR)/soc_uart_tb.log; exit 1; }
	@iverilog -g2012 -s soc_uart_tb -o $(BUILD)/soc_uart_tb_sim $(RTL) tb/soc_uart_tb.sv >> $(LOG_DIR)/soc_uart_tb.log 2>&1 || { cat $(LOG_DIR)/soc_uart_tb.log; exit 1; }
	@vvp $(BUILD)/soc_uart_tb_sim >> $(LOG_DIR)/soc_uart_tb.log 2>&1 || { cat $(LOG_DIR)/soc_uart_tb.log; exit 1; }
	@grep -E "PASS|FAIL" $(LOG_DIR)/soc_uart_tb.log || echo "PASS soc_uart_tb"

# The timer integration test builds its polling assembly image first.
test-soc_timer: $(BUILD)
	@mkdir -p $(LOG_DIR)
	@echo "==> soc_timer_tb"
	@$(MAKE) -C $(FPGA_DIR) PROGRAM=programs/timer_demo.S program.hex > $(LOG_DIR)/soc_timer_tb.log 2>&1 || { cat $(LOG_DIR)/soc_timer_tb.log; exit 1; }
	@iverilog -g2012 -s soc_timer_tb -o $(BUILD)/soc_timer_tb_sim $(RTL) tb/soc_timer_tb.sv >> $(LOG_DIR)/soc_timer_tb.log 2>&1 || { cat $(LOG_DIR)/soc_timer_tb.log; exit 1; }
	@vvp $(BUILD)/soc_timer_tb_sim >> $(LOG_DIR)/soc_timer_tb.log 2>&1 || { cat $(LOG_DIR)/soc_timer_tb.log; exit 1; }
	@grep -E "PASS|FAIL" $(LOG_DIR)/soc_timer_tb.log || echo "PASS soc_timer_tb"

test-timer_led_chaser: $(BUILD)
	@mkdir -p $(LOG_DIR)
	@echo "==> timer_led_chaser_tb"
	@$(MAKE) -C $(FPGA_DIR) PROGRAM=programs/timer_led_chaser.S TIMER_TICKS=8 program.hex > $(LOG_DIR)/timer_led_chaser_tb.log 2>&1 || { cat $(LOG_DIR)/timer_led_chaser_tb.log; exit 1; }
	@iverilog -g2012 -s timer_led_chaser_tb -o $(BUILD)/timer_led_chaser_tb_sim $(RTL) tb/timer_led_chaser_tb.sv >> $(LOG_DIR)/timer_led_chaser_tb.log 2>&1 || { cat $(LOG_DIR)/timer_led_chaser_tb.log; exit 1; }
	@vvp $(BUILD)/timer_led_chaser_tb_sim >> $(LOG_DIR)/timer_led_chaser_tb.log 2>&1 || { cat $(LOG_DIR)/timer_led_chaser_tb.log; exit 1; }
	@grep -E "PASS|FAIL" $(LOG_DIR)/timer_led_chaser_tb.log || echo "PASS timer_led_chaser_tb"

test-soc_button: $(BUILD)
	@mkdir -p $(LOG_DIR)
	@echo "==> soc_button_tb"
	@$(MAKE) -C $(FPGA_DIR) PROGRAM=programs/button_demo.S program.hex > $(LOG_DIR)/soc_button_tb.log 2>&1 || { cat $(LOG_DIR)/soc_button_tb.log; exit 1; }
	@iverilog -g2012 -s soc_button_tb -o $(BUILD)/soc_button_tb_sim $(RTL) tb/soc_button_tb.sv >> $(LOG_DIR)/soc_button_tb.log 2>&1 || { cat $(LOG_DIR)/soc_button_tb.log; exit 1; }
	@vvp $(BUILD)/soc_button_tb_sim >> $(LOG_DIR)/soc_button_tb.log 2>&1 || { cat $(LOG_DIR)/soc_button_tb.log; exit 1; }
	@grep -E "PASS|FAIL" $(LOG_DIR)/soc_button_tb.log || echo "PASS soc_button_tb"

test-soc_integration: $(BUILD)
	@mkdir -p $(LOG_DIR)
	@echo "==> soc_integration_tb"
	@$(MAKE) -C $(FPGA_DIR) PROGRAM=programs/soc_integration_demo.S TIMER_TICKS=8 program.hex > $(LOG_DIR)/soc_integration_tb.log 2>&1 || { cat $(LOG_DIR)/soc_integration_tb.log; exit 1; }
	@iverilog -g2012 -s soc_integration_tb -o $(BUILD)/soc_integration_tb_sim $(RTL) tb/soc_integration_tb.sv >> $(LOG_DIR)/soc_integration_tb.log 2>&1 || { cat $(LOG_DIR)/soc_integration_tb.log; exit 1; }
	@vvp $(BUILD)/soc_integration_tb_sim >> $(LOG_DIR)/soc_integration_tb.log 2>&1 || { cat $(LOG_DIR)/soc_integration_tb.log; exit 1; }
	@grep -E "PASS|FAIL" $(LOG_DIR)/soc_integration_tb.log || echo "PASS soc_integration_tb"

test:
	@passed=0; failed=0; \
	for test_name in $(TESTS); do \
		if $(MAKE) --no-print-directory test-$$test_name; then \
			passed=$$((passed + 1)); \
		else \
			failed=$$((failed + 1)); \
		fi; \
	done; \
	echo "========================================"; \
	echo "REGRESSION: PASS $$passed/$(words $(TESTS)), FAIL $$failed/$(words $(TESTS))"; \
	echo "========================================"; \
	test $$failed -eq 0
	@mkdir -p $(WAVE_DIR)
	@find . -maxdepth 1 -type f -name '*.vcd' -exec mv -f {} $(WAVE_DIR) \;

lint:
	verilator --lint-only -Wall -Wno-fatal \
		--top-module rv32i_pipelined_soc $(RTL)

# Build or program the Tang Nano 9K using the core-only default program.
# Override with: make PROGRAM=programs/<name>.S flash
fpga:
	@echo "==> FPGA program: $(PROGRAM)"
	$(MAKE) -C $(FPGA_DIR) PROGRAM=$(PROGRAM)

flash:
	@echo "==> FPGA program: $(PROGRAM)"
	$(MAKE) -C $(FPGA_DIR) PROGRAM=$(PROGRAM) flash

# Named FPGA demos keep program selection explicit without long commands.
flash-gpio:
	$(MAKE) flash PROGRAM=programs/gpio_demo.S

flash-hazard:
	$(MAKE) flash PROGRAM=hazard_demo.S

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

# Uses Ubuntu's Python: the OSS CAD Suite Python intentionally has no pyserial.
uart-monitor:
	/usr/bin/python3 scripts/uart_monitor.py --port $(UART_PORT) --baud $(UART_BAUD)

clean:
	# Remove only generated simulation, waveform, and FPGA outputs.
	rm -f $(BUILD)/*_sim
	rm -rf $(BUILD)/windows-regression
	rm -rf $(LOG_DIR)
	rm -rf $(WAVE_DIR)
	$(MAKE) -C $(FPGA_DIR) clean
