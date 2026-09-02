// IF/ID pipeline register
// Stores fecth-stage outputs for the decode stage.

module if_id_reg (

    input  logic        clk,
    input  logic        reset,

    input  logic [31:0] pc_in,
    input  logic [31:0] pc_plus4_in,
    input  logic [31:0] instruction_in,
    
    output logic [31:0] pc_out,
    output logic [31:0] pc_plus4_out,
    output logic [31:0] instruction_out
    
); 


// Capture fetch-stage values

    always_ff @(posedge clk) begin
    
        if (reset) begin
            pc_out          <= 32'b0;
            pc_plus4_out    <= 32'b0;
            instruction_out <= 32'h0000_0013;
        end
        else begin
            pc_out           <= pc_in;
            pc_plus4_out     <= pc_plus4_in;
            instruction_out  <= instruction_in;
        end
    end

endmodule
