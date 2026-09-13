// Memory-mapped UART transmit peripheral
module uart #(
    parameter integer CLOCK_FREQ = 27_000_000,
    parameter integer BAUD_RATE  = 115_200
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        write_enable,
    input  logic [31:0] write_data,
    output logic [31:0] read_data,
    output logic        tx
);

    logic busy;
    logic start;

    // A write while busy is ignored; software polls the status register first.
    assign start     = write_enable && !busy;
    assign read_data = {31'b0, busy};

    uart_tx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) tx_unit (
        .clk     (clk),
        .reset   (reset),
        .start   (start),
        .data_in (write_data[7:0]),
        .tx      (tx),
        .busy    (busy)
    );
endmodule
