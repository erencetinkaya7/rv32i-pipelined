`timescale 1ns/1ps

module branch_forwarding_tb;

    logic clk = 1'b0;
    logic reset = 1'b1;

    logic [31:0] instruction_data;
    logic [31:0] instruction_address;
    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;
    logic [31:0] debug_a0;

    rv32i_pipelined_core dut (
        .clk                 (clk),
        .reset               (reset),
        .instruction_data    (instruction_data),
        .instruction_address (instruction_address),
        .data_read_data      (32'b0),
        .data_address        (data_address),
        .data_write_data     (data_write_data),
        .data_mem_write      (data_mem_write),
        .data_funct3         (data_funct3),
        .debug_a0            (debug_a0)
    );

    always #5 clk = ~clk;

    // addi x5, x0, 1
    // beq  x5, x0, +12
    // The branch must not be taken. Its x5 operand requires MEM -> EX forwarding.
    always_comb begin
        case (instruction_address)
            32'h00: instruction_data = 32'h00100293;
            32'h04: instruction_data = 32'h00028663;
            default: instruction_data = 32'h00000013;
        endcase
    end

    initial begin
        $dumpfile("branch_forwarding.vcd");
        $dumpvars(0, branch_forwarding_tb);

        repeat (2) @(posedge clk);
        reset = 1'b0;

        wait (dut.ex_branch_enable === 1'b1);
        #1;

        if (dut.ex_branch_taken !== 1'b0)
            $fatal(1, "Branch used stale x5 and was incorrectly taken");

        $display("PASS: branch operand forwarding");
        $finish;
    end

endmodule
