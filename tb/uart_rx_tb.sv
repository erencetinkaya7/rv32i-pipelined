`timescale 1ns/1ps

module uart_rx_tb;
    localparam integer CLKS_PER_BIT = 10;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic rx = 1'b1;
    logic clear = 1'b0;

    logic [7:0] data_out;
    logic data_valid;
    logic framing_error;

    // Test clock
    always #5 clk = ~clk;

    // UART receiver under test
    uart_rx #(
        .CLOCK_FREQ(1000),
        .BAUD_RATE (100)
    ) dut (
        .clk           (clk),
        .reset         (reset),
        .rx            (rx),
        .clear         (clear),
        .data_out      (data_out),
        .data_valid    (data_valid),
        .framing_error (framing_error)
    );

    // Hold one UART bit value for one bit time.
    task automatic send_bit(input logic value);
        begin
            rx = value;
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

    // Send a frame with an invalid low stop bit.
    task automatic send_bad_stop_byte(input logic [7:0] value);
        integer bit_number;
        begin
            send_bit(1'b0);

            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1)
                send_bit(value[bit_number]);

            send_bit(1'b0);
        end
    endtask

    initial begin
        $dumpfile("build/waves/uart_rx.vcd");
        $dumpvars(0, uart_rx_tb);

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        send_byte(8'h55);

        wait (data_valid == 1'b1);
        #1;

        if (data_out !== 8'h55)
            $fatal(1, "FAIL: expected 0x55, got 0x%h", data_out);

        if (framing_error !== 1'b0)
            $fatal(1, "FAIL: valid frame raised framing_error");

        @(negedge clk);
        clear = 1'b1;
        @(posedge clk);
        #1;
        clear = 1'b0;

        send_byte(8'h00);
        wait (data_valid == 1'b1);
        #1;

        if (data_out !== 8'h00)
            $fatal(1, "FAIL: expected 0x00, got 0x%h", data_out);

        @(negedge clk);
        clear = 1'b1;
        @(posedge clk);
        #1;
        clear = 1'b0;

        send_byte(8'hFF);
        wait (data_valid == 1'b1);
        #1;

        if (data_out !== 8'hFF)
            $fatal(1, "FAIL: expected 0xFF, got 0x%h", data_out);

        @(negedge clk);
        clear = 1'b1;
        @(posedge clk);
        #1;
        clear = 1'b0;

        if (data_valid !== 1'b0)
            $fatal(1, "FAIL: clear did not lower data_valid");

        send_bad_stop_byte(8'hA5);
        wait (framing_error == 1'b1);
        #1;

        if (data_valid !== 1'b0)
            $fatal(1, "FAIL: invalid stop bit raised data_valid");

        if (framing_error !== 1'b1)
            $fatal(1, "FAIL: invalid stop bit did not raise framing_error");

        // Return to idle, then clear the reported framing error.
        rx = 1'b1;
        repeat (5) @(posedge clk);
        @(negedge clk);
        clear = 1'b1;
        @(posedge clk);
        #1;
        clear = 1'b0;

        if (framing_error !== 1'b0)
            $fatal(1, "FAIL: clear did not lower framing_error");

        // A short low pulse must not start a UART frame.
        @(negedge clk);
        rx = 1'b0;
        repeat (3) @(negedge clk);
        rx = 1'b1;
        repeat (20) @(posedge clk);

        if (data_valid !== 1'b0)
            $fatal(1, "FAIL: false start raised data_valid");

        if (framing_error !== 1'b0)
            $fatal(1, "FAIL: false start raised framing_error");

        $display("PASS: UART RX handles valid, bad-stop, false-start, and edge-byte frames");
        $finish;
    end

    initial begin
        repeat (700) @(posedge clk);
        $fatal(1, "FAIL: UART RX test timeout");
    end
endmodule
