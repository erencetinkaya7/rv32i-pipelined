`timescale 1ns/1ps

// Precise timer interrupt test at an instruction boundary.
module timer_interrupt_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic timer_irq = 1'b0;

    logic [31:0] instruction_data;
    logic [31:0] instruction_address;
    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;
    logic [31:0] debug_a0;

    logic saw_pending = 1'b0;
    logic saw_interrupt = 1'b0;
    logic saw_handler = 1'b0;
    logic saw_mret = 1'b0;

    always #5 clk = ~clk;

    instruction_memory #(
        .INIT_FILE("build/programs/program.hex")
    ) imem (
        .pc          (instruction_address),
        .instruction (instruction_data)
    );

    rv32i_pipelined_core dut (
        .clk                 (clk),
        .reset               (reset),
        .timer_irq           (timer_irq),
        .instruction_data    (instruction_data),
        .instruction_address (instruction_address),
        .data_read_data      (32'b0),
        .data_address        (data_address),
        .data_write_data     (data_write_data),
        .data_mem_write      (data_mem_write),
        .data_funct3         (data_funct3),
        .debug_a0            (debug_a0)
    );

    always @(negedge clk) begin
        if (!reset) begin
            if (dut.csr_mip[7])
                saw_pending <= 1'b1;

            if (dut.interrupt_take) begin
                saw_interrupt <= 1'b1;
                if (dut.if_id_pc !== 32'h0000_0014)
                    $fatal(1, "FAIL: interrupt boundary PC = 0x%h, expected 0x14",
                           dut.if_id_pc);
            end

            if (instruction_address == 32'h0000_0080)
                saw_handler <= 1'b1;

            if (dut.ex_mret)
                saw_mret <= 1'b1;

            if (debug_a0 == 32'd99)
                $fatal(1, "FAIL: instruction after MRET was not flushed");
        end
    end

    initial begin
        $dumpfile("build/waves/timer_interrupt.vcd");
        $dumpvars(0, timer_interrupt_tb);

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // Pulse the interrupt while the first a0 update waits in ID.
        wait (dut.if_id_valid && (dut.if_id_pc == 32'h0000_0010));
        @(negedge clk);
        timer_irq = 1'b1;
        @(negedge clk);
        timer_irq = 1'b0;

        repeat (35) @(posedge clk);
        #1;

        if (!saw_pending)
            $fatal(1, "FAIL: timer pulse was not latched in mip.MTIP");

        if (!saw_interrupt || !saw_handler || !saw_mret)
            $fatal(1, "FAIL: incomplete interrupt/handler/MRET sequence");

        if (dut.csr_mcause !== 32'h8000_0007)
            $fatal(1, "FAIL: mcause = 0x%h, expected 0x80000007",
                   dut.csr_mcause);

        if (dut.csr_mepc !== 32'h0000_0014)
            $fatal(1, "FAIL: mepc = 0x%h, expected 0x00000014",
                   dut.csr_mepc);

        if (dut.csr_mstatus[3] !== 1'b1)
            $fatal(1, "FAIL: MRET did not restore mstatus.MIE");

        if (dut.csr_mip[7] !== 1'b0)
            $fatal(1, "FAIL: timer interrupt remained pending after service");

        if (debug_a0 !== 32'd7)
            $fatal(1, "FAIL: interrupted instruction stream produced a0=%0d, expected 7",
                   debug_a0);

        if (dut.rf.registers[11] !== 32'd42)
            $fatal(1, "FAIL: handler marker a1=%0d, expected 42",
                   dut.rf.registers[11]);

        $display("PASS: timer interrupt preserved the instruction boundary and returned with MRET");
        $finish;
    end

    initial begin
        repeat (100) @(posedge clk);
        $fatal(1, "FAIL: timer interrupt test timeout");
    end
endmodule
