`timescale 1ns/1ps

module memory_tb;

    logic clk = 0;
    logic reset = 1;

    logic [31:0] instruction_data;
    logic [31:0] instruction_address;

    logic [31:0] data_read_data;
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

    // Data memory
    data_memory dmem (
        .clk(clk),
        .mem_write(data_mem_write),
        .address(data_address),
        .write_data(data_write_data),
        .funct3(data_funct3),
        .read_data(data_read_data)
    );

    always #5 clk = ~clk;

    // NOP-padded program: hazards are not implemented yet
    always_comb begin
        case (instruction_address)
            32'h00: instruction_data = 32'h01000093; // addi x1, x0, 16
            32'h04: instruction_data = 32'h00000013; // nop
            32'h08: instruction_data = 32'h00000013; // nop
            32'h0C: instruction_data = 32'h00000013; // nop

            32'h10: instruction_data = 32'h02A00113; // addi x2, x0, 42
            32'h14: instruction_data = 32'h00000013;
            32'h18: instruction_data = 32'h00000013;
            32'h1C: instruction_data = 32'h00000013;

            32'h20: instruction_data = 32'h0020A023; // sw x2, 0(x1)
            32'h24: instruction_data = 32'h00000013;
            32'h28: instruction_data = 32'h0000A183; // lw x3, 0(x1)

            default: instruction_data = 32'h00000013;
        endcase
    end

    initial begin
        $dumpfile("memory.vcd");
        $dumpvars(0, memory_tb);

        repeat (2) @(posedge clk);
        reset = 0;

        repeat (18) @(posedge clk);
        #1;

        if (dmem.memory[4] !== 32'd42)
            $fatal(1, "SW failed: memory[4] = %0d", dmem.memory[4]);

        if (dut.rf.registers[3] !== 32'd42)
            $fatal(1, "LW failed: x3 = %0d", dut.rf.registers[3]);

        $display("MEMORY STAGE PASS");
        $finish;
    end

endmodule
