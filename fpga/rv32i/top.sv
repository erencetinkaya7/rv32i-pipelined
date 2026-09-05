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

    logic [31:0] instruction_address;
    logic [31:0] instruction_data;

    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic [31:0] data_read_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;

    logic [31:0] debug_a0;

    // Reset synchronizer
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

    // Instruction memory
    instruction_memory #(
        .INIT_FILE("program.hex")
    ) imem (
        .pc          (instruction_address),
        .instruction (instruction_data)
    );

    // Data memory
    data_memory dmem (
        .clk        (clk),
        .mem_write  (data_mem_write),
        .address    (data_address),
        .write_data (data_write_data),
        .funct3     (data_funct3),
        .read_data  (data_read_data)
    );

    // Pipelined RV32I core
    rv32i_pipelined_core cpu (
        .clk                 (clk),
        .reset               (reset),

        .instruction_data    (instruction_data),
        .instruction_address (instruction_address),

        .data_read_data      (data_read_data),
        .data_address        (data_address),
        .data_write_data     (data_write_data),
        .data_mem_write      (data_mem_write),
        .data_funct3         (data_funct3),

        .debug_a0            (debug_a0)
    );

    // Onboard LEDs are active-low
    assign led = ~debug_a0[5:0];

    // UART is unused in baseline pipeline build
    assign uart_tx = 1'b1;

endmodule