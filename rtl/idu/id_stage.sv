module id_stage import rv32_pkg::*;(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    halt_i,
    input  logic                    branch_redirect_i,
    input  logic                    pipeline_stall_i,
    input  logic                    ex_stage_stall_i,
    input  logic                    id_flush_i,

    input  logic                    if_id_valid_q_i,
    input  logic [XLEN-1:0]         if_id_pc_q_i,
    input  logic [XLEN-1:0]         if_id_instr_q_i,
    
    input  logic                    id_ex_valid_q_i,
    input  logic [XLEN-1:0]         id_ex_pc_q_i,
    input  logic [4:0]              id_ex_op_q_i,
    input  logic [REG_ADDR_W-1:0]   id_ex_rd_q_i,
    input  logic [REG_ADDR_W-1:0]   id_ex_rs1_q_i,
    input  logic [REG_ADDR_W-1:0]   id_ex_rs2_q_i,
    input  logic                    id_ex_uses_rs1_q_i,
    input  logic                    id_ex_uses_rs2_q_i,
    input  logic                    id_ex_uses_rd_old_q_i,
    input  logic                    id_ex_rd_we_q_i,
    input  logic [XLEN-1:0]         id_ex_rs1_value_q_i,
    input  logic [XLEN-1:0]         id_ex_rs2_value_q_i,
    input  logic [XLEN-1:0]         id_ex_rd_old_value_q_i,
    input  logic [XLEN-1:0]         id_ex_imm_i_q_i,
    input  logic [XLEN-1:0]         id_ex_imm_s_q_i,
    input  logic [XLEN-1:0]         id_ex_imm_b_q_i,
    input  logic [XLEN-1:0]         id_ex_imm_u_q_i,
    input  logic [XLEN-1:0]         id_ex_imm_j_q_i,

    input  logic                    wb_we_i,
    input  logic [REG_ADDR_W-1:0]   wb_rd_i,
    input  logic [XLEN-1:0]         wb_data_i,

    output logic                    dec_legal_o,
    output logic                    dec_is_ebreak_o,
    output logic                    load_use_hazard_o,

    output logic                    id_ex_valid_d_o,
    output logic [XLEN-1:0]         id_ex_pc_d_o,
    output logic [4:0]              id_ex_op_d_o,
    output logic [REG_ADDR_W-1:0]   id_ex_rd_d_o,
    output logic [REG_ADDR_W-1:0]   id_ex_rs1_d_o,
    output logic [REG_ADDR_W-1:0]   id_ex_rs2_d_o,
    output logic                    id_ex_uses_rs1_d_o,
    output logic                    id_ex_uses_rs2_d_o,
    output logic                    id_ex_uses_rd_old_d_o,
    output logic                    id_ex_rd_we_d_o,
    output logic [XLEN-1:0]         id_ex_rs1_value_d_o,
    output logic [XLEN-1:0]         id_ex_rs2_value_d_o,
    output logic [XLEN-1:0]         id_ex_rd_old_value_d_o,
    output logic [XLEN-1:0]         id_ex_imm_i_d_o,
    output logic [XLEN-1:0]         id_ex_imm_s_d_o,
    output logic [XLEN-1:0]         id_ex_imm_b_d_o,
    output logic [XLEN-1:0]         id_ex_imm_u_d_o,
    output logic [XLEN-1:0]         id_ex_imm_j_d_o,

    output logic [XLEN-1:0]         debug_illegal_instr_o,
    output logic [XLEN-1:0]         debug_x3_o, 
    output logic [XLEN-1:0]         debug_x5_o,
    output logic [XLEN-1:0]         debug_x6_o,
    output logic [XLEN-1:0]         debug_x31_o
);

    logic [4:0] dec_op;
    logic [REG_ADDR_W-1:0] dec_rs1;
    logic [REG_ADDR_W-1:0] dec_rs2;
    logic [REG_ADDR_W-1:0] dec_rd;
    logic dec_rd_we;
    logic dec_uses_rs1;
    logic dec_uses_rs2;
    logic dec_uses_rd_old;
    logic [XLEN-1:0] dec_imm_i;
    logic [XLEN-1:0] dec_imm_s;
    logic [XLEN-1:0] dec_imm_b;
    logic [XLEN-1:0] dec_imm_u;
    logic [XLEN-1:0] dec_imm_j;
    logic [XLEN-1:0] rf_rdata0;
    logic [XLEN-1:0] rf_rdata1;
    logic [XLEN-1:0] rf_rdata2;
    logic load_use_hazard;

    decoder decoder_inst (
        .instr_i(if_id_instr_q_i),
        .instr_legal_o(dec_legal_o),
        .debug_illegal_instr_o(debug_illegal_instr_o),  
        .op_o(dec_op),
        .rs1_o(dec_rs1),
        .rs2_o(dec_rs2),
        .rd_o(dec_rd),
        .rd_we_o(dec_rd_we),
        .uses_rs1_o(dec_uses_rs1),
        .uses_rs2_o(dec_uses_rs2),
        .uses_rd_old_o(dec_uses_rd_old)
    );

    imm_gen imm_gen_inst (
        .instr_i(if_id_instr_q_i),
        .imm_i_o(dec_imm_i),
        .imm_s_o(dec_imm_s),
        .imm_b_o(dec_imm_b),
        .imm_u_o(dec_imm_u),
        .imm_j_o(dec_imm_j)
    );

    reg_file reg_file_inst (
        .clk(clk),
        .rst_n(rst_n),
        .raddr0_i(dec_rs1),
        .raddr1_i(dec_rs2),
        .raddr2_i(dec_rd),
        .rdata0_o(rf_rdata0),
        .rdata1_o(rf_rdata1),
        .rdata2_o(rf_rdata2),
        .we_i(wb_we_i),
        .waddr_i(wb_rd_i),
        .wdata_i(wb_data_i),
        .debug_x3_o(debug_x3_o),        
        .debug_x5_o(debug_x5_o),        
        .debug_x6_o(debug_x6_o),        
        .debug_x31_o(debug_x31_o)      
    );

    assign load_use_hazard = if_id_valid_q_i && id_ex_valid_q_i && (id_ex_op_q_i == OP_LW) && (id_ex_rd_q_i != '0) && ((dec_uses_rs1 && (dec_rs1 == id_ex_rd_q_i)) || (dec_uses_rs2 && (dec_rs2 == id_ex_rd_q_i)) || (dec_uses_rd_old && (dec_rd == id_ex_rd_q_i)));
    assign load_use_hazard_o = load_use_hazard;
    assign dec_is_ebreak_o = dec_legal_o && (dec_op == OP_EBREAK);

    always_comb begin
        /* hold by default */
        id_ex_valid_d_o = id_ex_valid_q_i;
        id_ex_pc_d_o = id_ex_pc_q_i;
        id_ex_op_d_o = id_ex_op_q_i;
        id_ex_rd_d_o = id_ex_rd_q_i;
        id_ex_rs1_d_o = id_ex_rs1_q_i;
        id_ex_rs2_d_o = id_ex_rs2_q_i;
        id_ex_uses_rs1_d_o = id_ex_uses_rs1_q_i;
        id_ex_uses_rs2_d_o = id_ex_uses_rs2_q_i;
        id_ex_uses_rd_old_d_o = id_ex_uses_rd_old_q_i;
        id_ex_rd_we_d_o = id_ex_rd_we_q_i;
        id_ex_rs1_value_d_o = id_ex_rs1_value_q_i;
        id_ex_rs2_value_d_o = id_ex_rs2_value_q_i;
        id_ex_rd_old_value_d_o = id_ex_rd_old_value_q_i;
        id_ex_imm_i_d_o = id_ex_imm_i_q_i;
        id_ex_imm_s_d_o = id_ex_imm_s_q_i;
        id_ex_imm_b_d_o = id_ex_imm_b_q_i;
        id_ex_imm_u_d_o = id_ex_imm_u_q_i;
        id_ex_imm_j_d_o = id_ex_imm_j_q_i;
        
        if (halt_i) begin
            id_ex_valid_d_o = 1'b0;
        end else if (branch_redirect_i) begin
            id_ex_valid_d_o = 1'b0;
        end else if (pipeline_stall_i) begin
            if (load_use_hazard && !ex_stage_stall_i) begin
                id_ex_valid_d_o = 1'b0;
            end else begin
                id_ex_valid_d_o = id_ex_valid_q_i;
            end
        end else if (id_flush_i) begin
            id_ex_valid_d_o = 1'b0;
        end else begin
            id_ex_valid_d_o = if_id_valid_q_i;
            id_ex_pc_d_o = if_id_pc_q_i;
            id_ex_op_d_o = dec_op;
            id_ex_rd_d_o = dec_rd;
            id_ex_rs1_d_o = dec_rs1;
            id_ex_rs2_d_o = dec_rs2;
            id_ex_uses_rs1_d_o = dec_uses_rs1;
            id_ex_uses_rs2_d_o = dec_uses_rs2;
            id_ex_uses_rd_old_d_o = dec_uses_rd_old;
            id_ex_rd_we_d_o = dec_rd_we;
            id_ex_rs1_value_d_o = dec_uses_rs1 ? rf_rdata0 : '0;
            id_ex_rs2_value_d_o = dec_uses_rs2 ? rf_rdata1 : '0;
            id_ex_rd_old_value_d_o = dec_uses_rd_old ? rf_rdata2 : '0;
            id_ex_imm_i_d_o = dec_imm_i;
            id_ex_imm_s_d_o = dec_imm_s;
            id_ex_imm_b_d_o = dec_imm_b;
            id_ex_imm_u_d_o = dec_imm_u;
            id_ex_imm_j_d_o = dec_imm_j;
        end
    end

endmodule : id_stage
