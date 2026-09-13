`timescale 1ns/1ps

// Integration test: a real CPU store must update the MMIO GPIO register.
module soc_gpio_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [31:0] debug_a0;
    logic [31:0] gpio_out;

    always #5 clk = ~clk;

    rv32i_pipelined_soc #(
        .IMEM_INIT_FILE("fpga/rv32i/program.hex")
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .debug_a0 (debug_a0),
        .gpio_out (gpio_out)
    );

    initial begin
        repeat (3) @(posedge clk);
        reset = 1'b0;

        repeat (20) @(posedge clk);
        if (gpio_out !== 32'd21) begin
            $display("FAIL: expected GPIO output 21, got %0d", gpio_out);
            $fatal;
        end

        $display("PASS: MMIO GPIO store updated gpio_out to %0d", gpio_out);
        $finish;
    end
endmodule
