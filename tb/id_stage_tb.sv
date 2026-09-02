`timescale 1ns/1ps

module id_stage_tb;

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

    // Simple instruction memory
    always_comb begin
        case (instruction_address)
            32'h0000_0000: instruction_data = 32'h0070_0293; // addi x5, x0, 7
            32'h0000_0004: instruction_data = 32'h1234_5337; // lui  x6, 0x12345
            default:       instruction_data = 32'h0000_0013; // nop
        endcase
    end

    initial begin
        $dumpfile("id_stage.vcd");
        $dumpvars(0, id_stage_tb);

        // Reset
        repeat (2) @(posedge clk);
        reset = 0;

        // ADDI enters IF/ID
        @(posedge clk);
        #1;

        // ADDI reaches ID/EX
        @(posedge clk);
        #1;

        if (dut.ex_pc !== 32'h0000_0000)
            $fatal(1, "ADDI PC wrong");

        if (dut.ex_rd !== 5'd5)
            $fatal(1, "ADDI rd wrong");

        if (dut.ex_immediate !== 32'd7)
            $fatal(1, "ADDI immediate wrong");

        if (dut.ex_opcode !== 7'b0010011)
            $fatal(1, "ADDI opcode wrong");

        if (dut.ex_reg_write !== 1'b1)
            $fatal(1, "ADDI reg_write wrong");

        if (dut.ex_alu_src !== 1'b1)
            $fatal(1, "ADDI alu_src wrong");

        // Next instruction should now be LUI
        @(posedge clk);
        #1;

        if (dut.ex_pc !== 32'h0000_0004)
            $fatal(1, "LUI PC wrong");

        if (dut.ex_rd !== 5'd6)
            $fatal(1, "LUI rd wrong");

        if (dut.ex_immediate !== 32'h1234_5000)
            $fatal(1, "LUI immediate wrong");

        if (dut.ex_opcode !== 7'b0110111)
            $fatal(1, "LUI opcode wrong");

        $display("ID STAGE PASS");
        $finish;
    end

endmodule
