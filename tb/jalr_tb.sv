`timescale 1ns/1ps

module jalr_tb;

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
            32'h00: instruction_data = 32'h02100093; // addi x1, x0, 33

            32'h04: instruction_data = 32'h00000013;
            32'h08: instruction_data = 32'h00000013;
            32'h0C: instruction_data = 32'h00000013;

            32'h10: instruction_data = 32'h000082E7; // jalr x5, 0(x1)

            // Wrong-path NOPs
            32'h14: instruction_data = 32'h00000013;
            32'h18: instruction_data = 32'h00000013;

            32'h20: instruction_data = 32'h00900513; // addi a0, x0, 9

            default: instruction_data = 32'h00000013;
        endcase
    end

    initial begin
        repeat (2) @(posedge clk);
        reset = 0;

        repeat (18) @(posedge clk);
        #1;

        if (debug_a0 !== 32'd9)
            $fatal(1, "JALR redirect failed");

        if (dut.rf.registers[5] !== 32'd20)
            $fatal(1, "JALR link failed: x5 = %0d", dut.rf.registers[5]);

        $display("JALR PASS");
        $finish;
    end

endmodule
