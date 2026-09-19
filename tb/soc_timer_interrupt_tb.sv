`timescale 1ns/1ps

// SoC test: hardware timer interrupts move LEDs while foreground code runs.
module soc_timer_interrupt_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic btn = 1'b1;
    logic uart_rx = 1'b1;

    logic [31:0] debug_a0;
    logic [31:0] gpio_out;
    logic uart_tx;

    logic saw_timer_cause = 1'b0;
    logic saw_handler = 1'b0;
    logic saw_led_2 = 1'b0;
    logic saw_led_4 = 1'b0;
    logic saw_mie_restored = 1'b0;

    always #5 clk = ~clk;

    rv32i_pipelined_soc #(
        .IMEM_INIT_FILE("build/programs/program.hex")
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .btn      (btn),
        .uart_rx  (uart_rx),
        .debug_a0 (debug_a0),
        .gpio_out (gpio_out),
        .uart_tx  (uart_tx)
    );

    always @(negedge clk) begin
        if (!reset) begin
            if (dut.cpu.csr_mcause == 32'h8000_0007)
                saw_timer_cause <= 1'b1;

            if (dut.instruction_address == 32'h0000_0080)
                saw_handler <= 1'b1;

            if (gpio_out[5:0] == 6'b000010)
                saw_led_2 <= 1'b1;

            if (gpio_out[5:0] == 6'b000100)
                saw_led_4 <= 1'b1;

            if (saw_timer_cause && dut.cpu.csr_mstatus[3])
                saw_mie_restored <= 1'b1;

            if ((gpio_out[5:0] != 6'b0) &&
                ((gpio_out[5:0] & (gpio_out[5:0] - 1'b1)) != 6'b0))
                $fatal(1, "FAIL: LED pattern is not one-hot: %b", gpio_out[5:0]);
        end
    end

    initial begin
        $dumpfile("build/waves/soc_timer_interrupt.vcd");
        $dumpvars(0, soc_timer_interrupt_tb);

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        wait (dut.cpu.rf.registers[11] >= 32'd2);

        // Press and release the active-low board button.
        @(negedge clk);
        btn = 1'b0;
        repeat (8) @(posedge clk);
        @(negedge clk);
        btn = 1'b1;

        repeat (450) @(posedge clk);
        #1;

        if (!saw_timer_cause || !saw_handler)
            $fatal(1, "FAIL: timer interrupt handler was not entered");

        if (!saw_led_2 || !saw_led_4)
            $fatal(1, "FAIL: timer handler did not produce LED patterns 1, 2, 4");

        if (!saw_mie_restored)
            $fatal(1, "FAIL: MRET did not restore global interrupt enable");

        if (dut.cpu.rf.registers[11] < 32'd4)
            $fatal(1, "FAIL: only %0d timer interrupts were serviced",
                   dut.cpu.rf.registers[11]);

        if (dut.cpu.rf.registers[20] !== 32'd1)
            $fatal(1, "FAIL: foreground button polling did not reverse direction");

        if (debug_a0 == 32'd0)
            $fatal(1, "FAIL: foreground heartbeat did not run");

        $display("PASS: timer IRQs moved LEDs, MRET resumed foreground work, and button reversed direction");
        $finish;
    end

    initial begin
        repeat (1200) @(posedge clk);
        $fatal(1, "FAIL: SoC timer interrupt test timeout");
    end
endmodule
