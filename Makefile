RTL := rtl/core/*.sv rtl/pipeline/*.sv rtl/memory/*.sv
BUILD := build

.PHONY: core test-if test-id test-ex-wb test-memory test-subword \
      test-branch test-jump test-jalr \
      test-arithmetic test-utype test-branches
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

test-ex-wb: $(BUILD)
	iverilog -g2012 -s ex_wb_tb \
	-o $(BUILD)/ex_wb_tb_sim $(RTL) tb/ex_wb_tb.sv
	vvp $(BUILD)/ex_wb_tb_sim

test-memory: $(BUILD)
	iverilog -g2012 -s memory_tb \
	-o $(BUILD)/memory_tb_sim $(RTL) tb/memory_tb.sv
	vvp $(BUILD)/memory_tb_sim

test-subword: $(BUILD)
	iverilog -g2012 -s subword_memory_tb \
	-o $(BUILD)/subword_memory_tb_sim $(RTL) tb/subword_memory_tb.sv
	vvp $(BUILD)/subword_memory_tb_sim

test-branch: $(BUILD)
	iverilog -g2012 -s branch_tb \
	-o $(BUILD)/branch_tb_sim $(RTL) tb/branch_tb.sv
	vvp $(BUILD)/branch_tb_sim

test-jump: $(BUILD)
	iverilog -g2012 -s jump_tb \
	-o $(BUILD)/jump_tb_sim $(RTL) tb/jump_tb.sv
	vvp $(BUILD)/jump_tb_sim

test-jalr: $(BUILD)
	iverilog -g2012 -s jalr_tb \
	-o $(BUILD)/jalr_tb_sim $(RTL) tb/jalr_tb.sv
	vvp $(BUILD)/jalr_tb_sim

test-arithmetic: $(BUILD)
	iverilog -g2012 -s arithmetic_regression_tb \
	-o $(BUILD)/arithmetic_regression_tb_sim $(RTL) tb/arithmetic_regression_tb.sv
	vvp $(BUILD)/arithmetic_regression_tb_sim

test-utype: $(BUILD)
	iverilog -g2012 -s u_type_tb \
	-o $(BUILD)/u_type_tb_sim $(RTL) tb/u_type_tb.sv
	vvp $(BUILD)/u_type_tb_sim

test-branches: $(BUILD)
	iverilog -g2012 -s branch_regression_tb \
	-o $(BUILD)/branch_regression_tb_sim $(RTL) tb/branch_regression_tb.sv
	vvp $(BUILD)/branch_regression_tb_sim

test: test-if test-id test-ex-wb test-memory test-subword \
      test-branch test-jump test-jalr \
      test-arithmetic test-utype test-branches

lint:
	verilator --lint-only -Wall -Wno-fatal \
	--top-module rv32i_pipelined_core $(RTL)

clean:
	rm -rf $(BUILD)
