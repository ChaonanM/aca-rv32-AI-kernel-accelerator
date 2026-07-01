module reg_file import rv32_pkg::*;(
    input  logic                     clk,
    input  logic                     rst_n,

    /* read ports*/
    input  logic [REG_ADDR_W-1:0]    raddr0_i,
    input  logic [REG_ADDR_W-1:0]    raddr1_i,
    input  logic [REG_ADDR_W-1:0]    raddr2_i,
    output logic [XLEN-1:0]          rdata0_o,
    output logic [XLEN-1:0]          rdata1_o,
    output logic [XLEN-1:0]          rdata2_o,

    /* write ports */
    input  logic                     we_i,
    input  logic [REG_ADDR_W-1:0]    waddr_i,
    input  logic [XLEN-1:0]          wdata_i,

    output logic [XLEN-1:0]     debug_x3_o,     // Expose x3 for the testbench
    output logic [XLEN-1:0]     debug_x5_o,     // Expose x5 for the testbench
    output logic [XLEN-1:0]     debug_x6_o,     // Expose x6 for the testbench
    output logic [XLEN-1:0]     debug_x31_o     // Expose x31 for the testbench
);

    logic [XLEN-1:0] regs_q [REG_COUNT-1:0];
    int unsigned reset_idx;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (reset_idx = 0; reset_idx < REG_COUNT; reset_idx = reset_idx + 1) begin
                regs_q[reset_idx] <= '0;
            end
        end else if (we_i && waddr_i != '0) begin
            regs_q[waddr_i] <= wdata_i;
        end
    end

    assign rdata0_o = (raddr0_i == '0) ? '0 : ((we_i && (waddr_i != '0) && (waddr_i == raddr0_i)) ? wdata_i : regs_q[raddr0_i]);
    assign rdata1_o = (raddr1_i == '0) ? '0 : ((we_i && (waddr_i != '0) && (waddr_i == raddr1_i)) ? wdata_i : regs_q[raddr1_i]);
    assign rdata2_o = (raddr2_i == '0) ? '0 : ((we_i && (waddr_i != '0) && (waddr_i == raddr2_i)) ? wdata_i : regs_q[raddr2_i]);
    assign debug_x3_o = regs_q[5'd3]; 
    assign debug_x5_o = regs_q[5'd5]; 
    assign debug_x6_o = regs_q[5'd6]; 
    assign debug_x31_o = regs_q[5'd31]; 

endmodule : reg_file
