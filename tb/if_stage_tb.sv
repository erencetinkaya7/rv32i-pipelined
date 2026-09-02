`timescale 1ns/1ps

module if_stage_tb;

    logic clk;
    logic reset;

    logic [31:0] instruction_address;
    logic [31:0] instruction_data;

    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;
    logic [31:0] debug_a0;

    integer errors;

    rv32i_pipelined_core dut (
        .clk(clk),
        .reset(reset),

        .instruction_address(instruction_address),
        .instruction_data(instruction_data),

        .data_address(data_address),
        .data_write_data(data_write_data),
        .data_mem_write(data_mem_write),
        .data_funct3(data_funct3),
        .data_read_data(32'b0),

        .debug_a0(debug_a0)
    );

    // Simple instruction source
    always_comb begin
        case (instruction_address)
            32'h0000_0000: instruction_data = 32'hAAAA_AAAA;
            32'h0000_0004: instruction_data = 32'hBBBB_BBBB;
            32'h0000_0008: instruction_data = 32'hCCCC_CCCC;
            default:       instruction_data = 32'h0000_0013; // NOP
        endcase
    end

    always #5 clk = ~clk;

    initial begin
        // Waveform dump
        $dumpfile("if_stage.vcd");
        $dumpvars(0, if_stage_tb);

        clk    = 0;
        reset  = 1;
        errors = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        @(posedge clk);
        #1;
        if (dut.if_id_pc !== 32'h0 ||
            dut.if_id_instruction !== 32'hAAAA_AAAA)
            errors = errors + 1;

        @(posedge clk);
        #1;
        if (dut.if_id_pc !== 32'h4 ||
            dut.if_id_instruction !== 32'hBBBB_BBBB)
            errors = errors + 1;

        @(posedge clk);
        #1;
        if (dut.if_id_pc !== 32'h8 ||
            dut.if_id_instruction !== 32'hCCCC_CCCC)
            errors = errors + 1;

        if (errors == 0)
            $display("IF STAGE PASS");
        else
            $display("IF STAGE FAIL: %0d errors", errors);

        $finish;
    end

endmodule
