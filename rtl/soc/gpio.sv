// Memory-mapped GPIO output register.

module gpio (
    input  logic        clk,
    input  logic        reset,
    input  logic        write_enable,
    input  logic [31:0] write_data,
    input  logic        btn,
    output logic [31:0] gpio_out,
    output logic [31:0] read_data
);

// Reset clears the LED output. A selected CPU store updates it on a clock edge.

    always_ff @(posedge clk) begin
        if (reset)
            gpio_out <= 32'b0;
        else if (write_enable)
            gpio_out <= write_data;
    end

    // The board button is active-low; software reads a press as bit 0 = 1.
    assign read_data = {31'b0, ~btn};

endmodule
