`timescale 1ns/1ps

// Integration test for fpga/rv32i/hazard_demo.S after it is compiled to HEX.
module hazard_demo_tb;

    logic clk = 1'b0;
    logic reset = 1'b1;

    logic [31:0] instruction_data;
    logic [31:0] instruction_address;
    logic [31:0] data_read_data;
    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;
    logic [31:0] debug_a0;

    // The generated program HEX acts as the instruction ROM.
    instruction_memory #(
        .INIT_FILE("fpga/rv32i/program.hex")
    ) imem (
        .pc          (instruction_address),
        .instruction (instruction_data)
    );

    // Use the real data memory so the store/load pair is end-to-end.
    data_memory dmem (
        .clk        (clk),
        .mem_write  (data_mem_write),
        .address    (data_address),
        .write_data (data_write_data),
        .funct3     (data_funct3),
        .read_data  (data_read_data)
    );

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

    initial begin
        repeat (3) @(posedge clk);
        reset = 1'b0;

        // Enough cycles for store/load, three loop iterations, and call/return.
        repeat (40) @(posedge clk);
        #1;

        if (dmem.memory[0] !== 32'd5)
            $fatal(1, "RAM value is wrong: %0d", dmem.memory[0]);
        if (dut.rf.registers[7] !== 32'd6)
            $fatal(1, "Load-use result t2 is wrong: %0d", dut.rf.registers[7]);
        if (dut.rf.registers[28] !== 32'd0)
            $fatal(1, "Loop counter t3 is wrong: %0d", dut.rf.registers[28]);
        if (dut.rf.registers[1] !== 32'h0000_0028)
            $fatal(1, "JAL link register ra is wrong: %h", dut.rf.registers[1]);
        if (debug_a0 !== 32'd19)
            $fatal(1, "Final result is wrong: a0 = %0d", debug_a0);

        $display("HAZARD DEMO PASS: RAM=5, t2=6, a0=19");
        $finish;
    end

endmodule
