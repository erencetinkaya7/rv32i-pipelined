`timescale 1ns/1ps

module timer_tb;
    logic        clk = 1'b0;
    logic        reset = 1'b1;
    logic        start = 1'b0;
    logic [31:0] count_in = 32'b0;
    logic        busy;
    logic        done;

    timer dut (
        .clk      (clk),
        .reset    (reset),
        .start    (start),
        .count_in (count_in),
        .busy     (busy),
        .done     (done)
    );

    always #5 clk = ~clk;

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // A non-zero write starts the countdown and raises busy.
        count_in = 32'd3;
        start    = 1'b1;
        @(negedge clk);
        start = 1'b0;
        if (busy !== 1'b1) $fatal(1, "FAIL: timer did not start");

        wait (done == 1'b1);
        if (busy !== 1'b0) $fatal(1, "FAIL: busy remained high after completion");

        // Completion is a pulse, not a sticky status bit.
        @(posedge clk);
        #1;
        if (done !== 1'b0) $fatal(1, "FAIL: done pulse lasted too long");

        // A zero write completes immediately without asserting busy.
        @(negedge clk);
        count_in = 32'd0;
        start    = 1'b1;
        @(negedge clk);
        start = 1'b0;
        if (done !== 1'b1 || busy !== 1'b0)
            $fatal(1, "FAIL: zero-count behavior is incorrect");

        $display("PASS: countdown timer behavior");
        $finish;
    end
endmodule
