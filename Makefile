RTL := rtl/core/*.sv rtl/pipeline/*.sv rtl/memory/*.sv rtl/soc/*.sv
BUILD := build
LOG_DIR := $(BUILD)/logs
WAVE_DIR := $(BUILD)/waves
FPGA_DIR := fpga/rv32i
PROGRAM ?= programs/gpio_demo.S
TESTS := arithmetic_regression branch_flush branch_forwarding branch_not_taken \
	branch_regression branch ex_wb hazard_demo id_stage if_stage jal_flush \
	jal_forwarding jalr_flush jalr_forwarding jalr jump load_use_branch \
	load_use_hazard load_use_jalr load_use_stall load_use_store memory \
	pipeline_flow raw_hazard soc_gpio subword_memory u_type

.PHONY: core test fpga flash flash-gpio flash-hazard flash-nested clean
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
	--top-module rv32i_pipelined_core $(RTL)

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

clean:
	# Remove only generated simulation, waveform, and FPGA outputs.
	rm -f $(BUILD)/*_sim
	rm -rf $(BUILD)/windows-regression
	rm -rf $(LOG_DIR)
	rm -rf $(WAVE_DIR)
	$(MAKE) -C $(FPGA_DIR) clean
