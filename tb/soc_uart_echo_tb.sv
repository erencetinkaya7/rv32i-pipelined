`timescale 1ns/1ps

// Integration test: CPU echoes UART RX bytes through UART TX.
module soc_uart_echo_tb;
    localparam integer CLKS_PER_BIT = 10;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic btn = 1'b1;
    logic uart_rx = 1'b1;
    logic [31:0] debug_a0;
    logic [31:0] gpio_out;
    logic uart_tx;

    always #5 clk = ~clk;

    rv32i_pipelined_soc #(
        .IMEM_INIT_FILE ("build/programs/program.hex"),
        .UART_CLOCK_FREQ(1000),
        .UART_BAUD_RATE (100)
    ) dut (
        .clk     (clk),
        .reset   (reset),
        .btn     (btn),
        .uart_rx (uart_rx),
        .debug_a0(debug_a0),
        .gpio_out(gpio_out),
        .uart_tx (uart_tx)
    );

    // Hold one UART bit value for one bit time.
    task automatic send_bit(input logic value);
        begin
            uart_rx = value;
            repeat (CLKS_PER_BIT) @(negedge clk);
        end
    endtask

    // Send one 8N1 frame, LSB first.
    task automatic send_byte(input logic [7:0] value);
        integer bit_number;
        begin
            send_bit(1'b0);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1)
                send_bit(value[bit_number]);
            send_bit(1'b1);
        end
    endtask

    task automatic check_bit(input logic expected);
        begin
            @(negedge clk);
            if (uart_tx !== expected)
                $fatal(1, "FAIL: UART TX = %b, expected %b", uart_tx, expected);
            repeat (CLKS_PER_BIT - 1) @(negedge clk);
        end
    endtask

    // Check one complete 8N1 frame, LSB first.
    task automatic check_byte(input logic [7:0] expected);
        integer bit_number;
        begin
            check_bit(1'b0);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1)
                check_bit(expected[bit_number]);
            check_bit(1'b1);
        end
    endtask

    initial begin
        $dumpfile("build/waves/soc_uart_echo.vcd");
        $dumpvars(0, soc_uart_echo_tb);

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        repeat (5) @(posedge clk);

        send_byte("K");
        @(negedge uart_tx);
        check_byte("K");

        repeat (10) @(posedge clk);
        send_byte(8'h3C);
        @(negedge uart_tx);
        check_byte(8'h3C);

        if (dut.uart_rx_data_valid !== 1'b0)
            $fatal(1, "FAIL: echo program did not clear data_valid");

        $display("PASS: CPU echoed two UART RX bytes through UART TX");
        $finish;
    end

    initial begin
        repeat (10000) @(posedge clk);
        $fatal(1, "FAIL: UART echo SoC integration timeout");
    end
endmodule
