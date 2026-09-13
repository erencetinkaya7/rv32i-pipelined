`timescale 1ns/1ps

// Integration test: CPU writes TIMER_LOAD then polls TIMER_STATUS through MMIO.
module soc_timer_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [31:0] debug_a0;
    logic [31:0] gpio_out;
    logic uart_tx;

    always #5 clk = ~clk;

    rv32i_pipelined_soc #(
        .IMEM_INIT_FILE("build/programs/program.hex")
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .debug_a0 (debug_a0),
        .gpio_out (gpio_out),
        .uart_tx  (uart_tx)
    );

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        repeat (80) @(posedge clk);
        if (debug_a0 !== 32'd1)
            $fatal(1, "FAIL: CPU did not observe timer completion; a0=%0d", debug_a0);

        $display("PASS: CPU timer MMIO load and status polling");
        $finish;
    end
endmodule
