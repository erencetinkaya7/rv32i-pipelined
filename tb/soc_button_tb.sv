`timescale 1ns/1ps

// Integration test: CPU polls the active-low button through GPIO_IN MMIO.
module soc_button_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic btn = 1'b1;      // Released on the physical board
    logic [31:0] debug_a0;
    logic [31:0] gpio_out;
    logic uart_tx;

    always #5 clk = ~clk;

    rv32i_pipelined_soc #(
        .IMEM_INIT_FILE("build/programs/program.hex")
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .btn      (btn),
        .debug_a0 (debug_a0),
        .gpio_out (gpio_out),
        .uart_tx  (uart_tx)
    );

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // With no press, software remains in its polling loop.
        repeat (30) @(posedge clk);
        if (gpio_out !== 32'b0)
            $fatal(1, "FAIL: GPIO changed before button press");

        // Drive between clock edges. The first stage changes first; the second
        // stage still holds the released value until the following clock edge.
        @(negedge clk);
        btn = 1'b0;
        @(posedge clk);
        #1;
        if (dut.gpio_periph.btn_meta !== 1'b0 || dut.gpio_periph.btn_sync !== 1'b1)
            $fatal(1, "FAIL: GPIO synchronizer first stage is incorrect");

        @(posedge clk);
        #1;
        if (dut.gpio_periph.btn_sync !== 1'b0)
            $fatal(1, "FAIL: synchronized button did not become pressed");

        repeat (40) @(posedge clk);
        if (gpio_out !== 32'd1)
            $fatal(1, "FAIL: button press did not light LED 1");

        $display("PASS: synchronized GPIO_IN button polling and GPIO_OUT write");
        $finish;
    end
endmodule
