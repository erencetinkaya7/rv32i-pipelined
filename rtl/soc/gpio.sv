// Memory-mapped GPIO output register.

module gpio (
    input  logic        clk,
    input  logic        reset,
    input  logic        write_enable,
    input  logic [31:0] write_data,
    output logic [31:0] gpio_out
);

// Reset clears the LED output. A selected CPU store updates it on a clock edge.

    always_ff @(posedge clk) begin
        if (reset)
            gpio_out <= 32'b0;
        else if (write_enable)
            gpio_out <= write_data;
    end

endmodule
