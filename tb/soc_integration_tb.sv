`timescale 1ns/1ps

// End-to-end SoC program: boot UART text, timer chaser, and button direction change.
module soc_integration_tb;
    localparam integer CLKS_PER_BIT = 10;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic btn = 1'b1;
    logic [31:0] debug_a0;
    logic [31:0] gpio_out;
    logic uart_tx;

    always #5 clk = ~clk;

    rv32i_pipelined_soc #(
        .IMEM_INIT_FILE("build/programs/program.hex"),
        .UART_CLOCK_FREQ(1000),
        .UART_BAUD_RATE (100)
    ) dut (
        .clk(clk), .reset(reset), .btn(btn), .debug_a0(debug_a0),
        .gpio_out(gpio_out), .uart_tx(uart_tx)
    );

    task automatic check_bit(input logic expected);
        begin
            @(negedge clk);
            if (uart_tx !== expected)
                $fatal(1, "FAIL: UART tx = %b, expected %b", uart_tx, expected);
            repeat (CLKS_PER_BIT - 1) @(negedge clk);
        end
    endtask

    task automatic expect_next_byte(input logic [7:0] expected);
        integer bit_number;
        begin
            @(negedge uart_tx);
            check_bit(1'b0);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1)
                check_bit(expected[bit_number]);
            check_bit(1'b1);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        expect_next_byte("S"); expect_next_byte("O");
        expect_next_byte("C"); expect_next_byte(" ");
        expect_next_byte("R"); expect_next_byte("E");
        expect_next_byte("A"); expect_next_byte("D");
        expect_next_byte("Y"); expect_next_byte(8'h0a);

        wait (gpio_out == 32'd1);
        btn = 1'b0;
        expect_next_byte("R");
        btn = 1'b1;

        wait (gpio_out == 32'd32);
        $display("PASS: integrated SoC program booted, reversed direction, and reported UART event");
        $finish;
    end

    // Never leave a failed integration test running indefinitely.
    initial begin
        repeat (5000) @(posedge clk);
        $fatal(1, "FAIL: integration timeout (PC=%h, GPIO=%h, UART=%b)",
               dut.cpu.pc, gpio_out, uart_tx);
    end
endmodule
