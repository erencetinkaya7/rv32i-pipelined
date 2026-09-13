`timescale 1ns/1ps

module jalr_flush_tb;

    logic clk = 0;
    logic reset = 1;
    logic [31:0] instruction_data;
    logic [31:0] instruction_address;
    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;
    logic [31:0] debug_a0;

    rv32i_pipelined_core dut (
        .clk(clk), .reset(reset),
        .instruction_data(instruction_data), .instruction_address(instruction_address),
        .data_read_data(32'b0),
        .data_address(data_address), .data_write_data(data_write_data),
        .data_mem_write(data_mem_write), .data_funct3(data_funct3),
        .debug_a0(debug_a0)
    );

    always #5 clk = ~clk;

    always_comb begin
        case (instruction_address)
            32'h00: instruction_data = 32'h0010_0593; // addi x11, x0, 1
            32'h04: instruction_data = 32'h0020_0613; // addi x12, x0, 2
            32'h08: instruction_data = 32'h0180_0293; // addi x5,  x0, 24
            32'h0C: instruction_data = 32'h0002_80E7; // jalr x1,  0(x5) -> 0x18
            32'h10: instruction_data = 32'h06F0_0593; // addi x11, x0, 111 (wrong path)
            32'h14: instruction_data = 32'h0DE0_0613; // addi x12, x0, 222 (wrong path)
            32'h18: instruction_data = 32'h0070_0513; // addi x10, x0, 7   (target)
            default: instruction_data = 32'h0000_0013;
        endcase
    end

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        repeat (16) @(posedge clk);
        #1;

        if (debug_a0 !== 32'd7)
            $fatal(1, "JALR target instruction did not execute: a0 = %0d", debug_a0);
        if (dut.rf.registers[1] !== 32'd16)
            $fatal(1, "JALR link value is wrong: x1 = %0d", dut.rf.registers[1]);
        if (dut.rf.registers[11] !== 32'd1)
            $fatal(1, "JALR wrong path wrote x11 = %0d", dut.rf.registers[11]);
        if (dut.rf.registers[12] !== 32'd2)
            $fatal(1, "JALR wrong path wrote x12 = %0d", dut.rf.registers[12]);

        $display("JALR FLUSH PASS");
        $finish;
    end

endmodule
