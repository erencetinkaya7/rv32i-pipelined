`timescale 1ns/1ps

module load_use_jalr_tb;

    logic clk = 1'b0;
    logic reset = 1'b1;

    logic [31:0] instruction_data;
    logic [31:0] instruction_address;
    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;
    logic [31:0] debug_a0;
    integer      hazard_cycles = 0;

    rv32i_pipelined_core dut (
        .clk                 (clk),
        .reset               (reset),
        .instruction_data    (instruction_data),
        .instruction_address (instruction_address),
        .data_read_data      (32'd16),
        .data_address        (data_address),
        .data_write_data     (data_write_data),
        .data_mem_write      (data_mem_write),
        .data_funct3         (data_funct3),
        .debug_a0            (debug_a0)
    );

    always #5 clk = ~clk;

    // lw   x5, 0(x0)      // x5 becomes 16
    // jalr x0, 0(x5)      // target must use the loaded x5 value
    always_comb begin
        case (instruction_address)
            32'h00: instruction_data = 32'h00002283;
            32'h04: instruction_data = 32'h00028067;
            default: instruction_data = 32'h00000013;
        endcase
    end

    always @(posedge clk) begin
        if (!reset && dut.load_use_hazard)
            hazard_cycles <= hazard_cycles + 1;
    end

    initial begin
        $dumpfile("load_use_jalr.vcd");
        $dumpvars(0, load_use_jalr_tb);

        repeat (2) @(posedge clk);
        reset = 1'b0;

        wait (dut.ex_jalr === 1'b1);
        #1;

        if (hazard_cycles !== 1)
            $fatal(1, "Expected one stall cycle, got %0d", hazard_cycles);

        if (dut.ex_jalr_target !== 32'd16 || dut.pc_next !== 32'd16)
            $fatal(1, "Load-use JALR failed: target = %0d", dut.ex_jalr_target);

        $display("PASS: load-use stall for JALR target");
        $finish;
    end

endmodule
