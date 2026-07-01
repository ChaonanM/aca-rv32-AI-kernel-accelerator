module mem_stage import rv32_pkg::*;(
    input  logic                    halt_i,
    input  logic                    ex_mem_valid_q_i,
    input  logic [4:0]              ex_mem_op_q_i,
    input  logic [REG_ADDR_W-1:0]   ex_mem_rd_q_i,
    input  logic                    ex_mem_rd_we_q_i,
    input  logic [XLEN-1:0]         ex_mem_result_q_i,
    input  logic [XLEN-1:0]         ex_mem_store_data_q_i,
    
    /* MEM Stage <-> Data Memory*/
    input  logic [XLEN-1:0]         dmem_rdata_i,
    output logic [XLEN-1:0]         dmem_addr_o,
    output logic [XLEN-1:0]         dmem_wdata_o,
    output logic                    dmem_we_o,

    output logic [XLEN-1:0]         mem_stage_wb_data_o,
    output logic                    ex_mem_forward_valid_o,
    
    output logic                    mem_wb_valid_d_o,
    output logic [4:0]              mem_wb_op_d_o,
    output logic [REG_ADDR_W-1:0]   mem_wb_rd_d_o,
    output logic                    mem_wb_rd_we_d_o,
    output logic [XLEN-1:0]         mem_wb_data_d_o
);

    assign dmem_addr_o = ex_mem_result_q_i;
    assign dmem_wdata_o = ex_mem_store_data_q_i;
    assign dmem_we_o = ex_mem_valid_q_i && (ex_mem_op_q_i == OP_SW) && !halt_i;
    assign mem_stage_wb_data_o = (ex_mem_op_q_i == OP_LW) ? dmem_rdata_i : ex_mem_result_q_i;
    assign ex_mem_forward_valid_o = ex_mem_valid_q_i && ex_mem_rd_we_q_i && (ex_mem_rd_q_i != '0);

    always_comb begin
        mem_wb_valid_d_o = ex_mem_valid_q_i;
        mem_wb_op_d_o = ex_mem_op_q_i;
        mem_wb_rd_d_o = ex_mem_rd_q_i;
        mem_wb_rd_we_d_o = ex_mem_rd_we_q_i;
        mem_wb_data_d_o = mem_stage_wb_data_o;
        if (halt_i) begin
            mem_wb_valid_d_o = 1'b0;
        end
    end

endmodule : mem_stage
