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

    logic [31:0] pc_next;
    logic [31:0] pc;
    logic [31:0] pc_plus4;

    assign instruction_address = pc;
    assign pc_plus4 = pc + 32'd4;
    
    always_ff @(posedge clk) begin
        if (reset)
            pc <= 32'b0;
        else
            pc <= pc_next;
    end


// IF/ID pipeline register

    logic [31:0] if_id_pc;
    logic [31:0] if_id_pc_plus4;
    logic [31:0] if_id_instruction;

    if_id_reg if_id (
        .clk(clk),
        .reset(reset),
        // Inputs
        .pc_in(pc),
        .pc_plus4_in(pc_plus4),
        .instruction_in(instruction_data),
        // Outputs
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
        .imm_sel(id_imm_sel),

        .immediate(id_immediate)
    );


 // MEM/WB pipeline signals
    logic [31:0] wb_alu_result;
    logic [31:0] wb_mem_data;
    logic [31:0] wb_pc_plus4;
    logic [4:0]  wb_rd;
    logic        wb_reg_write;
    logic [1:0]  wb_result_src;
    logic [31:0] wb_result;


    
// Register file
    register_file rf (
        .clk(clk),

        .write_enable(wb_reg_write),
        .rs1_addr(id_rs1),
        .rs2_addr(id_rs2),
        .rd_addr(wb_rd),
        .rd_data(wb_result),

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
    logic        ex_branch_taken;
    logic [31:0] ex_branch_target;
    logic [31:0] ex_jalr_target;
    logic        ex_pc_redirect;
    


// ID/EX pipeline register

    id_ex_reg id_ex (
        // Inputs
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
        // Outputs
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


// ALU

    alu alu_inst (
        .a           (ex_alu_a),
        .b           (ex_alu_b),
        .alu_control (ex_alu_control),

        .result      (ex_alu_result)
    );


// Branch decision
    branch_unit branch_unit_inst (
        .rs1_data      (ex_rs1_data),
        .rs2_data      (ex_rs2_data),
        .funct3        (ex_funct3),
        .branch_enable (ex_branch_enable),
        
        .branch_taken  (ex_branch_taken)
    );

    // Control flow targets
    assign ex_branch_target = ex_pc + ex_immediate;
    assign ex_jalr_target   = (ex_rs1_data + ex_immediate) & 32'hFFFF_FFFE;

    assign ex_pc_redirect = ex_branch_taken | ex_jump | ex_jalr;

    assign pc_next = ex_jalr
                ? ex_jalr_target
                : ex_pc_redirect
                ? ex_branch_target
                : pc_plus4;


// EX/MEM pipeline signals
    logic [31:0] mem_alu_result;
    logic [31:0] mem_rs2_data;
    logic [31:0] mem_pc_plus4;
    logic [4:0]  mem_rd;
    logic [2:0]  mem_funct3;
    logic        mem_reg_write;
    logic        mem_mem_write;
    logic [1:0]  mem_result_src;


// EX/MEM pipeline register
    ex_mem_reg ex_mem (
        .clk            (clk),
        .reset          (reset),

        .alu_result_in  (ex_alu_result),
        .rs2_data_in    (ex_rs2_data),
        .pc_plus4_in    (ex_pc_plus4),
        .rd_in          (ex_rd),
        .funct3_in      (ex_funct3),
        .reg_write_in   (ex_reg_write),
        .mem_write_in   (ex_mem_write),
        .result_src_in  (ex_result_src),

        .alu_result_out (mem_alu_result),
        .rs2_data_out   (mem_rs2_data),
        .pc_plus4_out   (mem_pc_plus4),
        .rd_out         (mem_rd),
        .funct3_out     (mem_funct3),
        .reg_write_out  (mem_reg_write),
        .mem_write_out  (mem_mem_write),
        .result_src_out (mem_result_src)
    );



// Data memory interface
    assign data_address    = mem_alu_result;
    assign data_write_data = mem_rs2_data;
    assign data_mem_write  = mem_mem_write;
    assign data_funct3     = mem_funct3;


// MEM/WB pipeline register
    mem_wb_reg mem_wb (
        .clk            (clk),
        .reset          (reset),

        .alu_result_in  (mem_alu_result),
        .mem_data_in    (data_read_data),
        .pc_plus4_in    (mem_pc_plus4),
        .rd_in          (mem_rd),
        .reg_write_in   (mem_reg_write),
        .result_src_in  (mem_result_src),

        .alu_result_out (wb_alu_result),
        .mem_data_out   (wb_mem_data),
        .pc_plus4_out   (wb_pc_plus4),
        .rd_out         (wb_rd),
        .reg_write_out  (wb_reg_write),
        .result_src_out (wb_result_src)
    );


// Writeback result selection
    always_comb begin
        case (wb_result_src)
            2'b00: wb_result = wb_alu_result;
            2'b01: wb_result = wb_mem_data;
            2'b10: wb_result = wb_pc_plus4;
            default: wb_result = 32'b0;
        endcase
    end
endmodule
   
