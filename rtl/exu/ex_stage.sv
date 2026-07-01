module ex_stage import rv32_pkg::*;(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    halt_i,
    
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

    /* forwarding signals */
    input  logic                    ex_mem_forward_valid_i,
    input  logic [REG_ADDR_W-1:0]   ex_mem_forward_rd_i,
    input  logic [XLEN-1:0]         ex_mem_forward_data_i,
    input  logic                    mem_wb_forward_valid_i,
    input  logic [REG_ADDR_W-1:0]   mem_wb_forward_rd_i,
    input  logic [XLEN-1:0]         mem_wb_forward_data_i,

    input  logic                    mul_active_q_i,
    input  logic                    mac_active_q_i,

    output logic                    ex_stage_stall_o,
    output logic                    branch_redirect_o,
    output logic [XLEN-1:0]         branch_target_o,
    
    output logic                    ex_mem_valid_d_o,
    output logic [4:0]              ex_mem_op_d_o,
    output logic [REG_ADDR_W-1:0]   ex_mem_rd_d_o,
    output logic                    ex_mem_rd_we_d_o,
    output logic [XLEN-1:0]         ex_mem_result_d_o,
    output logic [XLEN-1:0]         ex_mem_store_data_d_o,
    output logic                    mul_active_d_o,
    output logic                    mac_active_d_o
);

    logic [XLEN-1:0] ex_operand_a; 
    logic [XLEN-1:0] ex_operand_b;
    logic [XLEN-1:0] ex_accumulator;
    logic [XLEN-1:0] alu_lhs;   
    logic [XLEN-1:0] alu_rhs;
    logic [2:0] alu_op;
    logic [XLEN-1:0] alu_result;

    logic [1:0] branch_op;
    logic branch_taken;
    
    logic mul_start;
    logic mul_done;
    logic [XLEN-1:0] mul_result;
    logic ex_is_mul;
    
    logic mac_start;
    logic mac_done;
    logic [XLEN-1:0] mac_result;
    logic ex_is_mac;

    logic ex_stage_stall;

    alu alu_inst (
        .alu_op_i(alu_op),
        .lhs_i(alu_lhs),
        .rhs_i(alu_rhs),
        .result_o(alu_result)
    );

    branch_unit branch_unit_inst ( 
        .branch_op_i(branch_op),
        .lhs_i(ex_operand_a),
        .rhs_i(ex_operand_b),
        .taken_o(branch_taken)
    );

    mul_unit mul_unit_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(mul_start),
        .lhs_i(ex_operand_a),
        .rhs_i(ex_operand_b),
        .done_o(mul_done),
        .result_o(mul_result)
    );

    mac_unit mac_unit_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(mac_start),
        .lhs_i(ex_operand_a),
        .rhs_i(ex_operand_b),
        .accumulator_i(ex_accumulator),
        .done_o(mac_done),
        .result_o(mac_result)
    );

    /* forwarding */
    always_comb begin
        ex_operand_a = id_ex_rs1_value_q_i;
        if (id_ex_uses_rs1_q_i && ex_mem_forward_valid_i && (ex_mem_forward_rd_i == id_ex_rs1_q_i)) begin
            ex_operand_a = ex_mem_forward_data_i;
        end else if (id_ex_uses_rs1_q_i && mem_wb_forward_valid_i && (mem_wb_forward_rd_i == id_ex_rs1_q_i)) begin
            ex_operand_a = mem_wb_forward_data_i;
        end
    end

    always_comb begin
        ex_operand_b = id_ex_rs2_value_q_i;
        if (id_ex_uses_rs2_q_i && ex_mem_forward_valid_i && (ex_mem_forward_rd_i == id_ex_rs2_q_i)) begin
            ex_operand_b = ex_mem_forward_data_i;
        end else if (id_ex_uses_rs2_q_i && mem_wb_forward_valid_i && (mem_wb_forward_rd_i == id_ex_rs2_q_i)) begin
            ex_operand_b = mem_wb_forward_data_i;
        end
    end

    always_comb begin
        ex_accumulator = id_ex_rd_old_value_q_i;
        if (id_ex_uses_rd_old_q_i && ex_mem_forward_valid_i && (ex_mem_forward_rd_i == id_ex_rd_q_i)) begin
            ex_accumulator = ex_mem_forward_data_i;
        end else if (id_ex_uses_rd_old_q_i && mem_wb_forward_valid_i && (mem_wb_forward_rd_i == id_ex_rd_q_i)) begin
            ex_accumulator = mem_wb_forward_data_i;
        end
    end

    always_comb begin
        alu_op = ALU_ADD;
        alu_lhs = ex_operand_a;
        alu_rhs = ex_operand_b;
        unique case (id_ex_op_q_i)
            OP_SUB: alu_op = ALU_SUB;
            OP_ADDI: alu_rhs = id_ex_imm_i_q_i;
            OP_LW: alu_rhs = id_ex_imm_i_q_i;
            OP_SW: alu_rhs = id_ex_imm_s_q_i;
            OP_LUI: begin
                alu_op = ALU_PASS_B;
                alu_lhs = '0;
                alu_rhs = id_ex_imm_u_q_i;
            end
            default: ;
        endcase
    end

    always_comb begin
        branch_op = BR_NONE;
        unique case (id_ex_op_q_i)
            OP_BEQ: branch_op = BR_EQ;
            OP_BNE: branch_op = BR_NE;
            OP_BLT: branch_op = BR_LT;
            default: ;
        endcase
    end

    assign ex_is_mul = id_ex_valid_q_i && (id_ex_op_q_i == OP_MUL);
    assign mul_start = ex_is_mul && !mul_active_q_i && !halt_i;

    assign ex_is_mac = id_ex_valid_q_i && (id_ex_op_q_i == OP_MAC);
    assign mac_start = ex_is_mac && !mac_active_q_i && !halt_i;

    assign ex_stage_stall = (ex_is_mul && !mul_done) || (ex_is_mac && !mac_done);
    assign ex_stage_stall_o = ex_stage_stall;

    assign branch_redirect_o = id_ex_valid_q_i && ((id_ex_op_q_i == OP_JAL) || (((id_ex_op_q_i == OP_BEQ) || (id_ex_op_q_i == OP_BNE) || (id_ex_op_q_i == OP_BLT)) && branch_taken));
    assign branch_target_o = (id_ex_op_q_i == OP_JAL) ? (id_ex_pc_q_i + id_ex_imm_j_q_i) : (id_ex_pc_q_i + id_ex_imm_b_q_i);

    always_comb begin
        mul_active_d_o = mul_active_q_i;
        if (halt_i) begin
            mul_active_d_o = 1'b0;
        end else if (mul_start) begin
            mul_active_d_o = 1'b1;
        end else if (ex_is_mul && mul_done) begin
            mul_active_d_o = 1'b0;
        end
    end

    always_comb begin
        mac_active_d_o = mac_active_q_i;
        if (halt_i) begin
            mac_active_d_o = 1'b0;
        end else if (mac_start) begin
            mac_active_d_o = 1'b1;
        end else if (ex_is_mac && mac_done) begin
            mac_active_d_o = 1'b0;
        end
    end

    always_comb begin
        ex_mem_valid_d_o = id_ex_valid_q_i;
        ex_mem_op_d_o = id_ex_op_q_i;
        ex_mem_rd_d_o = id_ex_rd_q_i;
        ex_mem_rd_we_d_o = id_ex_rd_we_q_i;
        ex_mem_result_d_o = alu_result;
        ex_mem_store_data_d_o =  ex_operand_b;

        if (halt_i) begin
            ex_mem_valid_d_o = 1'b0;
        end else if (ex_stage_stall) begin
            ex_mem_valid_d_o = 1'b0;
        end else begin
            unique case (id_ex_op_q_i)
                OP_MUL: ex_mem_result_d_o = mul_result;
                OP_MAC: ex_mem_result_d_o = mac_result;
                OP_JAL: ex_mem_result_d_o = id_ex_pc_q_i + 32'd4;
                default: ex_mem_result_d_o = alu_result;
            endcase
        end
    end

endmodule : ex_stage
