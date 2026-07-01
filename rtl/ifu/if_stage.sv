module if_stage import rv32_pkg::*;(
    /* control signal */
    input  logic                fetch_stop_i,
    input  logic                pipeline_stall_i,
    input  logic                branch_redirect_i,
    input  logic                id_flush_i,
    
    input  logic [XLEN-1:0]     pc_q_i,
    input  logic                if_id_valid_q_i,
    input  logic [XLEN-1:0]     if_id_pc_q_i,
    input  logic [XLEN-1:0]     if_id_instr_q_i,
    input  logic [XLEN-1:0]     imem_rdata_i,
    input  logic [XLEN-1:0]     branch_target_i,
    
    output logic [XLEN-1:0]     imem_addr_o,
    output logic [XLEN-1:0]     pc_d_o,
    output logic                if_id_valid_d_o,
    output logic [XLEN-1:0]     if_id_pc_d_o,
    output logic [XLEN-1:0]     if_id_instr_d_o
);

    assign imem_addr_o = pc_q_i;

    always_comb begin
        /* hold by default*/
        pc_d_o = pc_q_i;
        if_id_valid_d_o = if_id_valid_q_i;
        if_id_pc_d_o = if_id_pc_q_i;
        if_id_instr_d_o = if_id_instr_q_i;

        if (fetch_stop_i) begin
            pc_d_o = pc_q_i;
            if_id_valid_d_o = 1'b0;
        end else if (branch_redirect_i) begin
            pc_d_o = branch_target_i;
            if_id_valid_d_o = 1'b0;
        end else if (pipeline_stall_i) begin
            pc_d_o = pc_q_i;
            if_id_valid_d_o = if_id_valid_q_i;
            if_id_pc_d_o = if_id_pc_q_i;
            if_id_instr_d_o = if_id_instr_q_i;
        end else if (id_flush_i) begin
            pc_d_o = pc_q_i;
            if_id_valid_d_o = 1'b0;
        end else begin
            pc_d_o = pc_q_i + 32'd4;
            if_id_valid_d_o = 1'b1;
            if_id_pc_d_o = pc_q_i;
            if_id_instr_d_o = imem_rdata_i;
        end
    end

endmodule : if_stage
