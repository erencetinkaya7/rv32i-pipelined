`timescale 1ns/1ps

module load_use_store_tb;

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
    integer      hazard_cycles = 0;

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

    // lw x5, 0(x0)
    // sw x5, 4(x0)
    // The store consumes the load result as rs2 and must stall once.
    always_comb begin
        case (instruction_address)
            32'h00: instruction_data = 32'h00002283;
            32'h04: instruction_data = 32'h00502223;
            default: instruction_data = 32'h00000013;
        endcase
    end

    always @(posedge clk) begin
        if (!reset && dut.load_use_hazard)
            hazard_cycles <= hazard_cycles + 1;
    end

    initial begin
        dmem.memory[0] = 32'd7;

        $dumpfile("load_use_store.vcd");
        $dumpvars(0, load_use_store_tb);

        repeat (2) @(posedge clk);
        reset = 1'b0;

        repeat (10) @(posedge clk);
        #1;

        if (hazard_cycles !== 1)
            $fatal(1, "Expected one stall cycle, got %0d", hazard_cycles);

        if (dmem.memory[1] !== 32'd7)
            $fatal(1, "Load-use store failed: memory[1] = %0d", dmem.memory[1]);

        $display("PASS: load-use stall for store data");
        $finish;
    end

endmodule
