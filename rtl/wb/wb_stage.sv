module wb_stage import rv32_pkg::*;(
    input  logic                    halt_i,
    input  logic                    mem_wb_valid_q_i,
    input  logic [4:0]              mem_wb_op_q_i,
    input  logic [REG_ADDR_W-1:0]   mem_wb_rd_q_i,
    input  logic                    mem_wb_rd_we_q_i,
    input  logic [XLEN-1:0]         mem_wb_data_q_i,

    output logic                    rf_we_o,
    output logic [REG_ADDR_W-1:0]   rf_waddr_o,
    output logic [XLEN-1:0]         rf_wdata_o,

    output logic                    mem_wb_forward_valid_o,

    output logic                    retire_valid_o,
    output logic                    retire_ebreak_o,
    output logic                    retire_add_o,
    output logic                    retire_mul_o,
    output logic                    retire_mac_o
);

    assign rf_we_o = mem_wb_valid_q_i && mem_wb_rd_we_q_i && !halt_i;
    assign rf_waddr_o = mem_wb_rd_q_i;
    assign rf_wdata_o = mem_wb_data_q_i;
    assign mem_wb_forward_valid_o = mem_wb_valid_q_i && mem_wb_rd_we_q_i && (mem_wb_rd_q_i != '0);
    assign retire_valid_o = mem_wb_valid_q_i && !halt_i;
    assign retire_ebreak_o = retire_valid_o && (mem_wb_op_q_i == OP_EBREAK);
    assign retire_add_o = retire_valid_o && (mem_wb_op_q_i == OP_ADD);
    assign retire_mul_o = retire_valid_o && (mem_wb_op_q_i == OP_MUL);
    assign retire_mac_o = retire_valid_o && (mem_wb_op_q_i == OP_MAC);
    
endmodule : wb_stage
