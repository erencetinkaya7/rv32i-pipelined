`timescale 1ns/1ps

module u_type_tb;

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

    function automatic logic [31:0] encode_u(
        input logic [19:0] imm,
        input logic [4:0]  rd,
        input logic [6:0]  opcode
    );
        encode_u = {imm, rd, opcode};
    endfunction

    always_comb begin
        case (instruction_address)
            32'h00: instruction_data =
                encode_u(20'h12345, 5'd5, 7'b0110111); // lui x5, 0x12345

            32'h04: instruction_data = 32'h00000013;
            32'h08: instruction_data = 32'h00000013;

            32'h0C: instruction_data =
                encode_u(20'h00001, 5'd6, 7'b0010111); // auipc x6, 0x1

            default: instruction_data = 32'h00000013;
        endcase
    end

    initial begin
        repeat (2) @(posedge clk);
        reset = 0;

        repeat (12) @(posedge clk);
        #1;

        if (dut.rf.registers[5] !== 32'h1234_5000)
            $fatal(1, "LUI failed: x5 = %h", dut.rf.registers[5]);

        if (dut.rf.registers[6] !== 32'h0000_100C)
            $fatal(1, "AUIPC failed: x6 = %h", dut.rf.registers[6]);

        $display("U-TYPE REGRESSION PASS");
        $finish;
    end

endmodule
