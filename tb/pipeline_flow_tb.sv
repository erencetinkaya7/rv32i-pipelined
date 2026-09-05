`timescale 1ns/1ps

module pipeline_flow_tb;

    logic clk = 0;
    logic reset = 1;

    logic [31:0] instruction_data;
    logic [31:0] instruction_address;

    logic [31:0] data_read_data = 0;
    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;
    logic [31:0] debug_a0;

    rv32i_pipelined_core dut (
        .clk(clk),
        .reset(reset),
        .instruction_data(instruction_data),
        .instruction_address(instruction_address),
        .data_read_data(data_read_data),
        .data_address(data_address),
        .data_write_data(data_write_data),
        .data_mem_write(data_mem_write),
        .data_funct3(data_funct3),
        .debug_a0(debug_a0)
    );

    always #5 clk = ~clk;

    always_comb begin
        case (instruction_address)
            32'h00: instruction_data = 32'h00100293; // addi x5, x0, 1
            32'h04: instruction_data = 32'h00200313; // addi x6, x0, 2
            32'h08: instruction_data = 32'h00300393; // addi x7, x0, 3
            32'h0C: instruction_data = 32'h00400513; // addi a0, x0, 4
            default: instruction_data = 32'h00000013;
        endcase
    end

    initial begin
        $dumpfile("pipeline_flow.vcd");
        $dumpvars(0, pipeline_flow_tb);

        repeat (2) @(posedge clk);
        reset = 0;

        repeat (12) @(posedge clk);
        #1;

        if (dut.rf.registers[5] !== 32'd1) $fatal(1, "x5 failed");
        if (dut.rf.registers[6] !== 32'd2) $fatal(1, "x6 failed");
        if (dut.rf.registers[7] !== 32'd3) $fatal(1, "x7 failed");
        if (debug_a0            !== 32'd4) $fatal(1, "a0 failed");

        $display("PIPELINE FLOW PASS");
        $finish;
    end

endmodule
