`timescale 1ns/1ps

module jalr_forwarding_tb;

    logic clk = 1'b0;
    logic reset = 1'b1;

    logic [31:0] instruction_data;
    logic [31:0] instruction_address;
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
        .data_read_data      (32'b0),
        .data_address        (data_address),
        .data_write_data     (data_write_data),
        .data_mem_write      (data_mem_write),
        .data_funct3         (data_funct3),
        .debug_a0            (debug_a0)
    );

    always #5 clk = ~clk;

    // addi x5, x0, 16
    // jalr x0, 0(x5)
    // JALR must use the forwarded x5 value and redirect to address 16.
    always_comb begin
        case (instruction_address)
            32'h00: instruction_data = 32'h01000293;
            32'h04: instruction_data = 32'h00028067;
            default: instruction_data = 32'h00000013;
        endcase
    end

    initial begin
        $dumpfile("jalr_forwarding.vcd");
        $dumpvars(0, jalr_forwarding_tb);

        repeat (2) @(posedge clk);
        reset = 1'b0;

        wait (dut.ex_jalr === 1'b1);
        #1;

        if (dut.ex_jalr_target !== 32'd16 || dut.pc_next !== 32'd16)
            $fatal(1, "JALR did not use forwarded x5: target = %0d", dut.ex_jalr_target);

        $display("PASS: JALR target forwarding");
        $finish;
    end

endmodule
