`timescale 1ns/1ps

module branch_regression_tb;

    logic clk = 0;
    logic reset = 1;
    logic [3:0] test_id;
    logic expected_taken;

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

    function automatic logic [31:0] encode_i(
        input logic [11:0] imm,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd
    );
        encode_i = {imm, rs1, funct3, rd, 7'b0010011};
    endfunction

    function automatic logic [31:0] encode_b(
        input logic [12:0] imm,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3
    );
        encode_b = {
            imm[12], imm[10:5],
            rs2, rs1, funct3,
            imm[4:1], imm[11],
            7'b1100011
        };
    endfunction

    logic [31:0] branch_instruction;

    always_comb begin
        case (test_id)
            0: branch_instruction = encode_b(13'd16, 5'd1, 5'd1, 3'b000); // BEQ
            1: branch_instruction = encode_b(13'd16, 5'd2, 5'd1, 3'b001); // BNE
            2: branch_instruction = encode_b(13'd16, 5'd1, 5'd3, 3'b100); // BLT  -1 < 1
            3: branch_instruction = encode_b(13'd16, 5'd3, 5'd1, 3'b101); // BGE   1 >= -1
            4: branch_instruction = encode_b(13'd16, 5'd2, 5'd1, 3'b110); // BLTU  1 < 2
            5: branch_instruction = encode_b(13'd16, 5'd1, 5'd2, 3'b111); // BGEU  2 >= 1
            6: branch_instruction = encode_b(13'd16, 5'd2, 5'd1, 3'b000); // BEQ false
            7: branch_instruction = encode_b(13'd16, 5'd1, 5'd1, 3'b001); // BNE false
            8: branch_instruction = encode_b(13'd16, 5'd3, 5'd1, 3'b100); // BLT 1 < -1 false
            9: branch_instruction = encode_b(13'd16, 5'd1, 5'd3, 3'b101); // BGE -1 >= 1 false
            10: branch_instruction = encode_b(13'd16, 5'd1, 5'd3, 3'b110); // BLTU ffffffff < 1 false
            11: branch_instruction = encode_b(13'd16, 5'd3, 5'd1, 3'b111); // BGEU 1 >= ffffffff false
            12: branch_instruction = encode_b(13'd16, 5'd3, 5'd3, 3'b100); // BLT equal false
            13: branch_instruction = encode_b(13'd16, 5'd3, 5'd3, 3'b110); // BLTU equal false
            14: branch_instruction = encode_b(13'd16, 5'd3, 5'd3, 3'b101); // BGE equal true
            15: branch_instruction = encode_b(13'd16, 5'd3, 5'd3, 3'b111); // BGEU equal true
            default: branch_instruction = 32'h00000013;
        endcase
    end

    always_comb begin
        case (instruction_address)
            32'h00: instruction_data = encode_i(12'd1,   0, 3'b000, 1); // x1 = 1
            32'h04: instruction_data = encode_i(12'd2,   0, 3'b000, 2); // x2 = 2
            32'h08: instruction_data = encode_i(12'hFFF, 0, 3'b000, 3); // x3 = -1

            32'h0C: instruction_data = 32'h00000013;
            32'h10: instruction_data = 32'h00000013;
            32'h14: instruction_data = 32'h00000013;

            32'h18: instruction_data = branch_instruction;

            // This test isolates branch comparisons; flush has separate tests.
            32'h1C: instruction_data = 32'h00000013;
            32'h20: instruction_data = 32'h00000013;

            32'h24: instruction_data = 32'h00000013;

            default: instruction_data = 32'h00000013;
        endcase
    end

    initial begin
        for (int t = 0; t < 16; t++) begin
            test_id = t[3:0];
            expected_taken = (t < 6 || t >= 14);

            reset = 1;
            repeat (2) @(posedge clk);
            @(negedge clk);
            reset = 0;

            wait (dut.ex_branch_enable === 1'b1);
            #1;

            if (dut.ex_branch_taken !== expected_taken)
                $fatal(1, "Branch %0d: expected taken=%b", t, expected_taken);

            if (dut.pc_next !== (expected_taken ? 32'h28 : 32'h24))
                $fatal(1, "Branch %0d wrong target: %h", t, dut.pc_next);

            @(posedge clk);
            #1;

            if (instruction_address !== (expected_taken ? 32'h28 : 32'h24))
                $fatal(1, "Branch %0d redirect failed", t);

            repeat (2) @(posedge clk);
        end

        $display("BRANCH REGRESSION PASS");
        $finish;
    end

    // Bound waits so a broken DUT fails instead of hanging.
    initial begin
        repeat (10000) @(posedge clk);
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
