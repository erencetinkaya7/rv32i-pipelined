`timescale 1ns/1ps

module subword_memory_tb;

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

    data_memory dmem (
        .clk        (clk),
        .mem_write  (data_mem_write),
        .address    (data_address),
        .write_data (data_write_data),
        .funct3     (data_funct3),
        .read_data  (data_read_data)
    );

    always #5 clk = ~clk;

    // NOP-padded program: hazards are not implemented yet
    always_comb begin
        case (instruction_address)

            32'h00: instruction_data = 32'h01000093; // addi x1, x0, 16
            32'h04: instruction_data = 32'h00000013; // nop
            32'h08: instruction_data = 32'h00000013; // nop
            32'h0C: instruction_data = 32'h00000013; // nop

            32'h10: instruction_data = 32'h00008183; // lb  x3, 0(x1)
            32'h14: instruction_data = 32'h0000C203; // lbu x4, 0(x1)
            32'h18: instruction_data = 32'h00209283; // lh  x5, 2(x1)
            32'h1C: instruction_data = 32'h0020D303; // lhu x6, 2(x1)

            32'h20: instruction_data = 32'h07A00393; // addi x7, x0, 0x7A
            32'h24: instruction_data = 32'h12300413; // addi x8, x0, 0x123

            32'h28: instruction_data = 32'h00000013;
            32'h2C: instruction_data = 32'h00000013;
            32'h30: instruction_data = 32'h00000013;

            32'h34: instruction_data = 32'h007080A3; // sb x7, 1(x1)
            32'h38: instruction_data = 32'h00809123; // sh x8, 2(x1)

            default: instruction_data = 32'h00000013;
        endcase
    end

    initial begin
        $dumpfile("subword_memory.vcd");
        $dumpvars(0, subword_memory_tb);

        // Initial word at address 16
        dmem.memory[4] = 32'h8001_8080;

        repeat (2) @(posedge clk);
        reset = 0;

        repeat (24) @(posedge clk);
        #1;

        if (dut.rf.registers[3] !== 32'hFFFF_FF80)
            $fatal(1, "LB failed");

        if (dut.rf.registers[4] !== 32'h0000_0080)
            $fatal(1, "LBU failed");

        if (dut.rf.registers[5] !== 32'hFFFF_8001)
            $fatal(1, "LH failed");

        if (dut.rf.registers[6] !== 32'h0000_8001)
            $fatal(1, "LHU failed");

        if (dmem.memory[4] !== 32'h0123_7A80)
            $fatal(1, "SB/SH failed: memory = %h", dmem.memory[4]);

        $display("SUBWORD MEMORY PASS");
        $finish;
    end

endmodule