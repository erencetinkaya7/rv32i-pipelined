// 5-stage pipelined RV32I processor core
// Exposes separate instruction and data memory interfaces.

module rv32i_pipelined_core (

    input  logic        clk,
    input  logic        reset,

    // Instruction interface
    input  logic [31:0] instruction_data,
    output logic [31:0] instruction_address,

    // Data interface
    input  logic [31:0] data_read_data,
    output logic [31:0] data_address,
    output logic [31:0] data_write_data,
    output logic        data_mem_write,
    output logic [2:0]  data_funct3,

    // Debug
    output logic [31:0] debug_a0

);


// Instruction Fetch

    logic [31:0] pc;
    logic [31:0] pc_plus4;
    assign instruction_address = pc;
    assign pc_plus4 = pc + 32'd4;
    
    always_ff @(posedge clk) begin
        if (reset)
            pc <= 32'b0;
        else
            pc <= pc_plus4;
    end


// IF/ID pipeline register

    logic [31:0] if_id_pc;
    logic [31:0] if_id_pc_plus4;
    logic [31:0] if_id_instruction;

    if_id_reg if_id (
        .clk(clk),
        .reset(reset),
        
        .pc_in(pc),
        .pc_plus4_in(pc_plus4),
        .instruction_in(instruction_data),
        
        .pc_out(if_id_pc),
        .pc_plus4_out(if_id_pc_plus4),
        .instruction_out(if_id_instruction)
    );    


// Instruction Decode

    logic [6:0] id_opcode;
    logic [4:0] id_rd;
    logic [2:0] id_funct3;
    logic [4:0] id_rs1;
    logic [4:0] id_rs2;
    logic [6:0] id_funct7;

    logic        id_reg_write;
    logic        id_alu_src;
    logic [2:0]  id_imm_sel;
    logic        id_mem_write;
    logic [1:0]  id_result_src;
    logic        id_branch_enable;
    logic        id_jump;
    logic        id_jalr;
    logic [1:0]  id_alu_a_sel;
    logic [31:0] id_immediate;    

    logic [31:0] id_rs1_data;
    logic [31:0] id_rs2_data;


    instruction_fields fields (
        .instruction(if_id_instruction),

        .opcode(id_opcode),
        .rd(id_rd),
        .funct3(id_funct3),
        .rs1(id_rs1),
        .rs2(id_rs2),
        .funct7(id_funct7)
    );

    
// Main instruction control
    control_unit control (
        .opcode(id_opcode),
        .reg_write(id_reg_write),
        .alu_src(id_alu_src),
        .imm_sel(id_imm_sel),
        .mem_write(id_mem_write),
        .result_src(id_result_src),
        .branch_enable(id_branch_enable),
        .jump(id_jump),
        .jalr(id_jalr),
        .alu_a_sel(id_alu_a_sel)
    );

// Immediate generation
    immediate_generator imm_gen (
        .instruction(if_id_instruction),
        .immediate(id_immediate),
        .imm_sel(id_imm_sel)
    );
    
    
// Register file
    register_file rf (
        .clk(clk),

        .write_enable(1'b0),   // WB stage not connected yet

        .rs1_addr(id_rs1),
        .rs2_addr(id_rs2),

        .rd_addr(5'b0),
        .rd_data(32'b0),

        .rs1_data(id_rs1_data),
        .rs2_data(id_rs2_data),

        .debug_a0(debug_a0)
);        


// ID/EX pipeline signals

    logic [31:0] ex_pc;
    logic [31:0] ex_pc_plus4;
    logic [31:0] ex_rs1_data;
    logic [31:0] ex_rs2_data;
    logic [31:0] ex_immediate;

    logic [4:0] ex_rs1;
    logic [4:0] ex_rs2;
    logic [4:0] ex_rd;
    logic [2:0] ex_funct3;
    logic [6:0] ex_funct7;
    logic [6:0] ex_opcode;

    logic       ex_reg_write;
    logic       ex_alu_src;
    logic [1:0] ex_alu_a_sel;
    logic       ex_mem_write;
    logic [1:0] ex_result_src;
    logic       ex_branch_enable;
    logic       ex_jump;
    logic       ex_jalr;
    logic [3:0] ex_alu_control;
    logic [31:0] ex_alu_a;
    logic [31:0] ex_alu_b;
    logic [31:0] ex_alu_result;


// ID/EX pipeline register

    id_ex_reg id_ex (
        .clk(clk),
        .reset(reset),

        .pc_in(if_id_pc),
        .pc_plus4_in(if_id_pc_plus4),
        .rs1_data_in(id_rs1_data),
        .rs2_data_in(id_rs2_data),
        .immediate_in(id_immediate),

        .rs1_in(id_rs1),
        .rs2_in(id_rs2),
        .rd_in(id_rd),
        .funct3_in(id_funct3),
        .funct7_in(id_funct7),
        .opcode_in(id_opcode),

        .reg_write_in(id_reg_write),
        .alu_src_in(id_alu_src),
        .alu_a_sel_in(id_alu_a_sel),
        .mem_write_in(id_mem_write),
        .result_src_in(id_result_src),
        .branch_enable_in(id_branch_enable),
        .jump_in(id_jump),
        .jalr_in(id_jalr),

        .pc_out(ex_pc),
        .pc_plus4_out(ex_pc_plus4),
        .rs1_data_out(ex_rs1_data),
        .rs2_data_out(ex_rs2_data),
        .immediate_out(ex_immediate),

        .rs1_out(ex_rs1),
        .rs2_out(ex_rs2),
        .rd_out(ex_rd),
        .funct3_out(ex_funct3),
        .funct7_out(ex_funct7),
        .opcode_out(ex_opcode),

        .reg_write_out(ex_reg_write),
        .alu_src_out(ex_alu_src),
        .alu_a_sel_out(ex_alu_a_sel),
        .mem_write_out(ex_mem_write),
        .result_src_out(ex_result_src),
        .branch_enable_out(ex_branch_enable),
        .jump_out(ex_jump),
        .jalr_out(ex_jalr)
);

// EX Stage - ALU Decode

    alu_decoder alu_decoder_inst (
        .opcode(ex_opcode),
        .funct3(ex_funct3),
        .funct7(ex_funct7),

        .alu_control(ex_alu_control)
    );


// EX - Stage - ALU Operand Selection

    always_comb begin
        case (ex_alu_a_sel)
            2'b00: ex_alu_a = ex_rs1_data;
            2'b01: ex_alu_a = ex_pc;
            2'b10: ex_alu_a = 32'b0;
            default: ex_alu_a = 32'b0;
        endcase

    ex_alu_b = ex_alu_src ? ex_immediate : ex_rs2_data;
    end


endmodule
   
