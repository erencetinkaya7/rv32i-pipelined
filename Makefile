RTL := rtl/core/*.sv rtl/pipeline/*.sv rtl/memory/*.sv
BUILD := build

.PHONY: core test test-if test-id lint clean

$(BUILD):
	mkdir -p $(BUILD)

core: $(BUILD)
	iverilog -g2012 -s rv32i_pipelined_core \
	-o $(BUILD)/pipeline_sim $(RTL)

test-if: $(BUILD)
	iverilog -g2012 -s if_stage_tb \
	-o $(BUILD)/if_stage_tb_sim $(RTL) tb/if_stage_tb.sv
	vvp $(BUILD)/if_stage_tb_sim

test-id: $(BUILD)
	iverilog -g2012 -s id_stage_tb \
	-o $(BUILD)/id_stage_tb_sim $(RTL) tb/id_stage_tb.sv
	vvp $(BUILD)/id_stage_tb_sim

test: test-if test-id

lint:
	verilator --lint-only -Wall -Wno-fatal \
	--top-module rv32i_pipelined_core $(RTL)

clean:
	rm -rf $(BUILD)
