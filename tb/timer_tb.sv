`timescale 1ns/1ps

module timer_tb;
    logic clk = 0, reset = 1, start = 0;
    logic [31:0] count_in = 0;
    logic busy, done;

    timer dut (.clk(clk), .reset(reset), .start(start),
               .count_in(count_in), .busy(busy), .done(done));
    always #5 clk = ~clk;

    // Drive on falling edges; inspect after the next rising edge.
    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    task automatic check(input logic expected_busy, expected_done);
        if (busy !== expected_busy || done !== expected_done)
            $fatal(1, "Timer: busy/done=%b/%b, expected %b/%b",
                   busy, done, expected_busy, expected_done);
    endtask

    initial begin
        tick(); check(0, 0);
        @(negedge clk); reset = 0; start = 1; count_in = 3;
        tick(); check(1, 0);
        @(negedge clk); start = 0;
        tick(); check(1, 0);
        // A new request while busy must not reload the counter.
        @(negedge clk); start = 1; count_in = 99;
        tick(); check(1, 0);
        @(negedge clk); start = 0;
        tick(); check(0, 1);
        tick(); check(0, 0);

        @(negedge clk); start = 1; count_in = 0;
        tick(); check(0, 1);
        @(negedge clk); start = 0;
        tick(); check(0, 0);

        @(negedge clk); start = 1; count_in = 1;
        tick(); check(1, 0);
        @(negedge clk); start = 0;
        tick(); check(0, 1);
        tick(); check(0, 0);

        // Reset cancels an active countdown and wins over start.
        @(negedge clk); start = 1; count_in = 100;
        tick(); check(1, 0);
        @(negedge clk); reset = 1;
        tick(); check(0, 0);
        @(negedge clk); reset = 0; start = 0;
        repeat (3) begin tick(); check(0, 0); end

        $display("PASS: timer exact count, 0/1, busy write, pulse and active reset");
        $finish;
    end
endmodule
