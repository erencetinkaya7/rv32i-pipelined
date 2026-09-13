`timescale 1ns/1ps

// Integration test: timer polling advances visible GPIO patterns.
module timer_led_chaser_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [31:0] debug_a0;
    logic [31:0] gpio_out;
    logic uart_tx;
    logic [31:0] previous_gpio = 32'b0;
    integer transition_count = 0;

    always #5 clk = ~clk;

    rv32i_pipelined_soc #(
        .IMEM_INIT_FILE("fpga/rv32i/program.hex")
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .debug_a0 (debug_a0),
        .gpio_out (gpio_out),
        .uart_tx  (uart_tx)
    );

    initial begin
        repeat (3) @(posedge clk);
        reset = 1'b0;

        repeat (400) begin
            @(posedge clk);
            if (gpio_out != previous_gpio) begin
                transition_count = transition_count + 1;
                case (transition_count)
                    1: if (gpio_out !== 32'd1) $fatal(1, "FAIL: first pattern is %0d", gpio_out);
                    2: if (gpio_out !== 32'd2) $fatal(1, "FAIL: second pattern is %0d", gpio_out);
                    3: if (gpio_out !== 32'd4) $fatal(1, "FAIL: third pattern is %0d", gpio_out);
                endcase
                previous_gpio = gpio_out;
            end
            if (transition_count == 3) begin
                $display("PASS: timer-driven GPIO chaser patterns 1, 2, 4");
                $finish;
            end
        end

        $fatal(1, "FAIL: timer-driven GPIO patterns did not advance");
    end
endmodule
