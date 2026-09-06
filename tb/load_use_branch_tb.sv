`timescale 1ns/1ps

module load_use_branch_tb;

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
        .data_read_data      (32'd7),
        .data_address        (data_address),
        .data_write_data     (data_write_data),
        .data_mem_write      (data_mem_write),
        .data_funct3         (data_funct3),
        .debug_a0            (debug_a0)
    );

    always #5 clk = ~clk;

    // lw  x5, 0(x0)      // x5 becomes 7
    // beq x5, x0, +12    // must not be taken after the load-use stall
    always_comb begin
        case (instruction_address)
            32'h00: instruction_data = 32'h00002283;
            32'h04: instruction_data = 32'h00028663;
            default: instruction_data = 32'h00000013;
        endcase
    end

    always @(posedge clk) begin
        if (!reset && dut.load_use_hazard)
            hazard_cycles <= hazard_cycles + 1;
    end

    initial begin
        $dumpfile("load_use_branch.vcd");
        $dumpvars(0, load_use_branch_tb);

        repeat (2) @(posedge clk);
        reset = 1'b0;

        wait (dut.ex_branch_enable === 1'b1);
        #1;

        if (hazard_cycles !== 1)
            $fatal(1, "Expected one stall cycle, got %0d", hazard_cycles);

        if (dut.ex_branch_taken !== 1'b0)
            $fatal(1, "Load-use branch used stale x5 and was incorrectly taken");

        $display("PASS: load-use stall for branch operand");
        $finish;
    end

endmodule
