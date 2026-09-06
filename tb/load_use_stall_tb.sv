`timescale 1ns/1ps

module load_use_stall_tb;

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

    always #5 clk = ~clk;

    // Simple combinational memory response: lw returns 7 from address 0.
    assign data_read_data = (data_address == 32'd0) ? 32'd7 : 32'd0;

    // lw   x5, 0(x0)
    // addi x10, x5, 1
    // The addi must wait one cycle, then receive x5 through WB -> EX forwarding.
    always_comb begin
        case (instruction_address)
            32'h00: instruction_data = 32'h00002283;
            32'h04: instruction_data = 32'h00128513;
            default: instruction_data = 32'h00000013;
        endcase
    end

    always @(posedge clk) begin
        if (!reset && dut.load_use_hazard)
            hazard_cycles <= hazard_cycles + 1;
    end

    initial begin
        $dumpfile("load_use_stall.vcd");
        $dumpvars(0, load_use_stall_tb);

        repeat (2) @(posedge clk);
        reset = 1'b0;

        repeat (10) @(posedge clk);
        #1;

        if (hazard_cycles !== 1)
            $fatal(1, "Expected one stall cycle, got %0d", hazard_cycles);

        if (debug_a0 !== 32'd8)
            $fatal(1, "Load-use stall failed: a0 = %0d", debug_a0);

        $display("PASS: load-use stall and WB -> EX forwarding");
        $finish;
    end

endmodule
