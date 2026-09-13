// Pipelined RV32I SoC

module rv32i_pipelined_soc #(
    parameter IMEM_INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        reset,

    output logic [31:0] debug_a0,
    output logic [31:0] gpio_out
);

    // MMIO address map
    localparam logic [31:0] GPIO_OUT_ADDR = 32'h1000_0000;

    // Instruction bus
    logic [31:0] instruction_address;
    logic [31:0] instruction_data;

    // CPU data bus
    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic [31:0] data_read_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;

    // RAM read path
    logic [31:0] ram_read_data;

    // Address decoder
    logic ram_selected;
    logic gpio_out_selected;

    // RAM: 0x0000_0000 - 0x0000_00FF
    assign ram_selected      = (data_address[31:8] == 24'b0);
    assign gpio_out_selected = (data_address == GPIO_OUT_ADDR);

    // Instruction memory
    instruction_memory #(
        .INIT_FILE(IMEM_INIT_FILE)
    ) imem (
        .pc          (instruction_address),
        .instruction (instruction_data)
    );

    // Pipelined CPU
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

    // Data RAM
    data_memory dmem (
        .clk        (clk),
        .mem_write  (data_mem_write && ram_selected),
        .address    (data_address),
        .write_data (data_write_data),
        .funct3     (data_funct3),
        .read_data  (ram_read_data)
    );

    // GPIO output register
    gpio gpio_periph (
        .clk          (clk),
        .reset        (reset),
        .write_enable (data_mem_write && gpio_out_selected),
        .write_data   (data_write_data),
        .gpio_out     (gpio_out)
    );

    // Read-data mux
    always_comb begin
        if (ram_selected)
            data_read_data = ram_read_data;
        else
            data_read_data = 32'b0;
    end

endmodule
