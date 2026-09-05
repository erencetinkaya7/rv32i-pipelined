`timescale 1ns/1ps

module arithmetic_regression_tb;

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
        .clk                 (clk),
        .reset               (reset),
        .instruction_data    (instruction_data),
        .instruction_address (instruction_address),
        .data_read_data      (data_read_data),
        .data_address        (data_address),
        .data_write_data     (data_write_data),
        .data_mem_write      (data_mem_write),
        .data_funct3         (data_funct3),
        .debug_a0            (debug_a0)
    );

    always #5 clk = ~clk;

    // R-type encoder
    function automatic logic [31:0] encode_r(
        input logic [6:0] funct7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd
    );
        encode_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
    endfunction

    // I-type encoder
    function automatic logic [31:0] encode_i(
        input logic [11:0] imm,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3,
        input logic [4:0]  rd
    );
        encode_i = {imm, rs1, funct3, rd, 7'b0010011};
    endfunction

    always_comb begin
        case (instruction_address)

            // Source registers
            32'h00: instruction_data = encode_i(12'd10, 5'd0, 3'b000, 5'd1); // x1 = 10
            32'h04: instruction_data = encode_i(12'd3,  5'd0, 3'b000, 5'd2); // x2 = 3
            32'h08: instruction_data = encode_i(12'hFF8, 5'd0, 3'b000, 5'd3); // x3 = -8
            32'h0C: instruction_data = encode_i(12'd1,  5'd0, 3'b000, 5'd4); // x4 = 1

            // Wait for source writeback
            32'h10: instruction_data = 32'h00000013;
            32'h14: instruction_data = 32'h00000013;
            32'h18: instruction_data = 32'h00000013;

            // R-type
            32'h1C: instruction_data = encode_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd5);  // ADD
            32'h20: instruction_data = encode_r(7'b0100000, 5'd2, 5'd1, 3'b000, 5'd6);  // SUB
            32'h24: instruction_data = encode_r(7'b0000000, 5'd2, 5'd1, 3'b111, 5'd7);  // AND
            32'h28: instruction_data = encode_r(7'b0000000, 5'd2, 5'd1, 3'b110, 5'd8);  // OR
            32'h2C: instruction_data = encode_r(7'b0000000, 5'd2, 5'd1, 3'b100, 5'd9);  // XOR
            32'h30: instruction_data = encode_r(7'b0000000, 5'd2, 5'd1, 3'b001, 5'd10); // SLL
            32'h34: instruction_data = encode_r(7'b0000000, 5'd2, 5'd1, 3'b101, 5'd11); // SRL
            32'h38: instruction_data = encode_r(7'b0100000, 5'd4, 5'd3, 3'b101, 5'd12); // SRA
            32'h3C: instruction_data = encode_r(7'b0000000, 5'd4, 5'd3, 3'b010, 5'd13); // SLT
            32'h40: instruction_data = encode_r(7'b0000000, 5'd4, 5'd3, 3'b011, 5'd14); // SLTU

            // I-type
            32'h44: instruction_data = encode_i(12'd5,  5'd1, 3'b000, 5'd15); // ADDI
            32'h48: instruction_data = encode_i(12'd6,  5'd1, 3'b111, 5'd16); // ANDI
            32'h4C: instruction_data = encode_i(12'd5,  5'd1, 3'b110, 5'd17); // ORI
            32'h50: instruction_data = encode_i(12'd3,  5'd1, 3'b100, 5'd18); // XORI
            32'h54: instruction_data = encode_i(12'b0000000_00010, 5'd1, 3'b001, 5'd19); // SLLI
            32'h58: instruction_data = encode_i(12'b0000000_00001, 5'd1, 3'b101, 5'd20); // SRLI
            32'h5C: instruction_data = encode_i(12'b0100000_00010, 5'd3, 3'b101, 5'd21); // SRAI
            32'h60: instruction_data = encode_i(12'd0,  5'd3, 3'b010, 5'd22); // SLTI
            32'h64: instruction_data = encode_i(12'd1,  5'd3, 3'b011, 5'd23); // SLTIU

            default: instruction_data = 32'h00000013;
        endcase
    end

    initial begin
        repeat (2) @(posedge clk);
        reset = 0;

        repeat (40) @(posedge clk);
        #1;

        // R-type
        if (dut.rf.registers[5]  !== 32'd13)       $fatal(1, "ADD failed");
        if (dut.rf.registers[6]  !== 32'd7)        $fatal(1, "SUB failed");
        if (dut.rf.registers[7]  !== 32'd2)        $fatal(1, "AND failed");
        if (dut.rf.registers[8]  !== 32'd11)       $fatal(1, "OR failed");
        if (dut.rf.registers[9]  !== 32'd9)        $fatal(1, "XOR failed");
        if (dut.rf.registers[10] !== 32'd80)       $fatal(1, "SLL failed");
        if (dut.rf.registers[11] !== 32'd1)        $fatal(1, "SRL failed");
        if (dut.rf.registers[12] !== 32'hFFFF_FFFC) $fatal(1, "SRA failed");
        if (dut.rf.registers[13] !== 32'd1)        $fatal(1, "SLT failed");
        if (dut.rf.registers[14] !== 32'd0)        $fatal(1, "SLTU failed");

        // I-type
        if (dut.rf.registers[15] !== 32'd15)        $fatal(1, "ADDI failed");
        if (dut.rf.registers[16] !== 32'd2)         $fatal(1, "ANDI failed");
        if (dut.rf.registers[17] !== 32'd15)        $fatal(1, "ORI failed");
        if (dut.rf.registers[18] !== 32'd9)         $fatal(1, "XORI failed");
        if (dut.rf.registers[19] !== 32'd40)        $fatal(1, "SLLI failed");
        if (dut.rf.registers[20] !== 32'd5)         $fatal(1, "SRLI failed");
        if (dut.rf.registers[21] !== 32'hFFFF_FFFE) $fatal(1, "SRAI failed");
        if (dut.rf.registers[22] !== 32'd1)         $fatal(1, "SLTI failed");
        if (dut.rf.registers[23] !== 32'd0)         $fatal(1, "SLTIU failed");

        $display("ARITHMETIC REGRESSION PASS");
        $finish;
    end

endmodule