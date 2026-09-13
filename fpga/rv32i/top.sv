module top (
    input  logic       clk,
    input  logic       btn,
    input  logic       reset_btn,

    output logic [5:0] led,
    output logic       uart_tx
);

    logic reset;
    logic [7:0] reset_counter = 8'hFF;

    logic reset_btn_meta = 1'b1;
    logic reset_btn_sync = 1'b1;

    logic [31:0] debug_a0;
    logic [31:0] gpio_out;

    // Synchronize the physical reset button before using it as reset.
    always_ff @(posedge clk) begin
        reset_btn_meta <= reset_btn;
        reset_btn_sync <= reset_btn_meta;
    end

    // Power-up reset
    always_ff @(posedge clk) begin
        if (reset_counter != 8'd0)
            reset_counter <= reset_counter - 1'b1;
    end

    assign reset = (reset_counter != 8'd0) || !reset_btn_sync;

    // The SoC owns memory and MMIO; the board top owns reset and physical pins.
    rv32i_pipelined_soc #(
        .IMEM_INIT_FILE ("program.hex"),
        // Tang Nano 9K onboard BL702 USB-UART default.
        .UART_BAUD_RATE (115_200)
    ) soc (
        .clk      (clk),
        .reset    (reset),
        .btn      (btn),
        .debug_a0 (debug_a0),
        .gpio_out (gpio_out),
        .uart_tx  (uart_tx)
    );

    // Onboard LEDs are active-low
    assign led = ~gpio_out[5:0];

endmodule
