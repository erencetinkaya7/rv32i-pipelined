`timescale 1ns/1ps

// Integration test: CPU software sends a one-time UART message over MMIO.
module soc_uart_tb;
    localparam integer CLKS_PER_BIT = 10;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [31:0] debug_a0;
    logic [31:0] gpio_out;
    logic uart_tx;

    always #5 clk = ~clk;

    rv32i_pipelined_soc #(
        .IMEM_INIT_FILE ("build/programs/program.hex"),
        .UART_CLOCK_FREQ(1000),
        .UART_BAUD_RATE (100)
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .debug_a0 (debug_a0),
        .gpio_out (gpio_out),
        .uart_tx  (uart_tx)
    );

    task automatic check_bit(input logic expected);
        begin
            @(negedge clk);
            if (uart_tx !== expected) begin
                $display("FAIL: UART tx = %b, expected %b", uart_tx, expected);
                $fatal;
            end
            repeat (CLKS_PER_BIT - 1) @(negedge clk);
        end
    endtask

    // Check one complete 8N1 frame for an expected byte.
    task automatic check_byte(input logic [7:0] expected);
        integer bit_number;
        begin
            check_bit(1'b0);    // Start bit
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1)
                check_bit(expected[bit_number]);
            check_bit(1'b1);    // Stop bit
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // Each call waits for the next start bit and checks its 8N1 frame.
        @(negedge uart_tx);
        check_byte("R");
        @(negedge uart_tx); check_byte("V");
        @(negedge uart_tx); check_byte("3");
        @(negedge uart_tx); check_byte("2");
        @(negedge uart_tx); check_byte("I");
        @(negedge uart_tx); check_byte(" ");
        @(negedge uart_tx); check_byte("U");
        @(negedge uart_tx); check_byte("A");
        @(negedge uart_tx); check_byte("R");
        @(negedge uart_tx); check_byte("T");
        @(negedge uart_tx); check_byte(" ");
        @(negedge uart_tx); check_byte("O");
        @(negedge uart_tx); check_byte("K");
        @(negedge uart_tx); check_byte("!");
        @(negedge uart_tx); check_byte(8'h0a);

        $display("PASS: MMIO UART transmitted one-time message");
        $finish;
    end
    // Bound waits so a broken DUT fails instead of hanging.
    initial begin
        repeat (10000) @(posedge clk);
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
