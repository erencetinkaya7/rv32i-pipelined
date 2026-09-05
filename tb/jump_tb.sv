`timescale 1ns/1ps

module jump_tb;

    logic clk = 0;
    logic reset = 1;

    logic [31:0] instruction_data;
    logic [31:0] instruction_address;

    logic [31:0] data_read_data = 32'b0;
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
            32'h00: instruction_data = 32'h00C000EF; // jal x1, +12
            32'h04: instruction_data = 32'h00000013; // nop
            32'h08: instruction_data = 32'h00000013; // nop

            32'h0C: instruction_data = 32'h00700513; // addi a0, x0, 7

            default: instruction_data = 32'h00000013;
        endcase
    end

    initial begin
        $dumpfile("jump.vcd");
        $dumpvars(0, jump_tb);

        repeat (2) @(posedge clk);
        reset = 0;

        repeat (12) @(posedge clk);
        #1;

        if (debug_a0 !== 32'd7)
            $fatal(1, "JAL redirect failed");

        if (dut.rf.registers[1] !== 32'd4)
            $fatal(1, "JAL link failed: x1 = %0d", dut.rf.registers[1]);

        $display("JAL PASS");
        $finish;
    end

endmodule