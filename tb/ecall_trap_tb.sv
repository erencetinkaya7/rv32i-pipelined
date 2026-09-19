`timescale 1ns/1ps

// Integration test for ECALL entry, CSR access and MRET return.
module ecall_trap_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;

    logic [31:0] instruction_data;
    logic [31:0] instruction_address;
    logic [31:0] data_read_data = 32'b0;
    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;
    logic [31:0] debug_a0;
    logic        saw_trap_handler  = 1'b0;
    logic        saw_trap_state    = 1'b0;
    logic        saw_handler_value = 1'b0;
    logic        saw_return_value  = 1'b0;

    always #5 clk = ~clk;

    // Program ROM with ECALL at 0x04 and the handler at 0x80.
    instruction_memory #(
        .INIT_FILE("build/programs/program.hex")
    ) imem (
        .pc          (instruction_address),
        .instruction (instruction_data)
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

    // Track the complete trap and return sequence.
    always @(negedge clk) begin
        if (!reset) begin
            if (instruction_address == 32'h0000_0080)
                saw_trap_handler <= 1'b1;

            if ((dut.csr_mepc == 32'h0000_0004) &&
                (dut.csr_mcause == 32'd11))
                saw_trap_state <= 1'b1;

            if (debug_a0 == 32'd42)
                saw_handler_value <= 1'b1;

            if (debug_a0 == 32'd7) begin
                if (!saw_handler_value)
                    $fatal(1, "FAIL: main program resumed before handler completed");
                saw_return_value <= 1'b1;
            end

            if (debug_a0 == 32'd99)
                $fatal(1, "FAIL: instruction after MRET was not flushed");
        end
    end

    initial begin
        $dumpfile("build/waves/ecall_trap.vcd");
        $dumpvars(0, ecall_trap_tb);

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        repeat (35) @(posedge clk);
        #1;

        if (!saw_trap_handler)
            $fatal(1, "FAIL: PC never reached mtvec 0x80");

        if (!saw_trap_state)
            $fatal(1, "FAIL: trap state mepc=0x04 and mcause=11 was not observed");

        if (!saw_handler_value)
            $fatal(1, "FAIL: handler result a0=42 was not observed");

        if (!saw_return_value)
            $fatal(1, "FAIL: main program did not resume after MRET");

        if (dut.csr_mepc !== 32'h0000_0008)
            $fatal(1, "FAIL: mepc = 0x%h, expected return address 0x00000008", dut.csr_mepc);

        if (dut.csr_mcause !== 32'd11)
            $fatal(1, "FAIL: mcause = %0d, expected 11", dut.csr_mcause);

        if (debug_a0 !== 32'd7)
            $fatal(1, "FAIL: final a0 = %0d, expected 7", debug_a0);

        $display("PASS: ECALL entered the handler, updated mepc, and returned with MRET");
        $finish;
    end

    initial begin
        repeat (80) @(posedge clk);
        $fatal(1, "FAIL: ECALL trap test timeout");
    end
endmodule
