`timescale 1ns/1ps

module jal_forwarding_tb;

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

    // jal  x5, +4      // x5 receives PC + 4 = 4
    // addi x10, x5, 1  // must receive x5 through MEM -> EX forwarding
    always_comb begin
        case (instruction_address)
            32'h00: instruction_data = 32'h004002EF;
            32'h04: instruction_data = 32'h00128513;
            default: instruction_data = 32'h00000013;
        endcase
    end

    initial begin
        $dumpfile("jal_forwarding.vcd");
        $dumpvars(0, jal_forwarding_tb);

        repeat (2) @(posedge clk);
        reset = 1'b0;

        wait (dut.ex_opcode === 7'b0010011 && dut.ex_rd === 5'd10);
        #1;

        if (dut.forward_a !== 2'b10 || dut.ex_alu_result !== 32'd5)
            $fatal(1, "JAL link forwarding failed: forward_a=%b result=%0d",
                dut.forward_a, dut.ex_alu_result);

        $display("PASS: JAL link forwarding");
        $finish;
    end

endmodule
