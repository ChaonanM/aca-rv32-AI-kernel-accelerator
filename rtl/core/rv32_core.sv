module rv32_core import rv32_pkg::*;(
    input  logic            clk,
    input  logic            rst_n,

    /* Instruction Memory <-> IF Stage */
    output logic [XLEN-1:0] imem_addr_o,
    input  logic [XLEN-1:0] imem_rdata_i,

    /* Data Memory <-> MEM Stage */
    output logic [XLEN-1:0] dmem_addr_o,
    input  logic [XLEN-1:0] dmem_rdata_i,
    output logic [XLEN-1:0] dmem_wdata_o,
    output logic            dmem_we_o,

    output logic            halt_o,
    output logic            illegal_o,
    output logic [XLEN-1:0] cycle_count_o,
    output logic [XLEN-1:0] instr_count_o,
    output logic [XLEN-1:0] add_count_o,
    output logic [XLEN-1:0] mul_count_o,
    output logic [XLEN-1:0] mac_count_o,
    output logic [XLEN-1:0] debug_illegal_instr_o,  // Expose illegal instruction for debug.
    output logic [XLEN-1:0] debug_x3_o,             // Expose x3 for the smoke test.
    output logic [XLEN-1:0] debug_x5_o,             // Expose x5 for the smoke test.
    output logic [XLEN-1:0] debug_x6_o,             // Expose x6 for the smoke test.
    output logic [XLEN-1:0] debug_x31_o             // Expose x31 for smoke-test failure-code checking.
);

    logic                   halt_q;
    logic                   halt_d;
    logic                   drain_q;
    logic                   drain_d;
    logic                   illegal_q;
    logic                   illegal_d;
    logic [XLEN-1:0]        pc_q; 
    logic [XLEN-1:0]        pc_d; 
    logic [XLEN-1:0]        cycle_count_q; 
    logic [XLEN-1:0]        cycle_count_d; 
    logic [XLEN-1:0]        instr_count_q;
    logic [XLEN-1:0]        instr_count_d;
    logic [XLEN-1:0]        add_count_q;
    logic [XLEN-1:0]        add_count_d;
    logic [XLEN-1:0]        mul_count_q;
    logic [XLEN-1:0]        mul_count_d;
    logic [XLEN-1:0]        mac_count_q;
    logic [XLEN-1:0]        mac_count_d;

    /* IF/ID */
    logic                   if_id_valid_q; 
    logic                   if_id_valid_d; 
    logic [XLEN-1:0]        if_id_pc_q; 
    logic [XLEN-1:0]        if_id_pc_d; 
    logic [XLEN-1:0]        if_id_instr_q; 
    logic [XLEN-1:0]        if_id_instr_d;
    
    /* ID */
    logic                   dec_legal; 
    logic                   dec_is_ebreak;
    logic                   decode_accept;          // Report when the current IF/ID instruction may be consumed this cycle.
    logic                   ebreak_decode_event;    // Pulse when ID accepts EBREAK and must stop all younger fetches.
    logic                   illegal_decode_event;   // Pulse when ID rejects an instruction and must drain older work.
    logic                   fetch_stop;             // Stop IF while a drain request is new, pending, or already completed.
    logic                   pipeline_empty_next;    // Report that all next-state pipeline valid bits are clear.
    logic                   load_use_hazard;
    logic                   pipeline_stall;
    logic                   id_flush;

    /* ID/EX */
    logic                   id_ex_valid_q;
    logic                   id_ex_valid_d;
    logic [XLEN-1:0]        id_ex_pc_q;
    logic [XLEN-1:0]        id_ex_pc_d;
    logic [4:0]             id_ex_op_q;
    logic [4:0]             id_ex_op_d;
    logic [REG_ADDR_W-1:0]  id_ex_rd_q;
    logic [REG_ADDR_W-1:0]  id_ex_rd_d;
    logic [REG_ADDR_W-1:0]  id_ex_rs1_q;
    logic [REG_ADDR_W-1:0]  id_ex_rs1_d;
    logic [REG_ADDR_W-1:0]  id_ex_rs2_q;
    logic [REG_ADDR_W-1:0]  id_ex_rs2_d;
    logic                   id_ex_uses_rs1_q;
    logic                   id_ex_uses_rs1_d;
    logic                   id_ex_uses_rs2_q;
    logic                   id_ex_uses_rs2_d;
    logic                   id_ex_uses_rd_old_q;
    logic                   id_ex_uses_rd_old_d;
    logic                   id_ex_rd_we_q; 
    logic                   id_ex_rd_we_d; 
    logic [XLEN-1:0]        id_ex_rs1_value_q; 
    logic [XLEN-1:0]        id_ex_rs1_value_d; 
    logic [XLEN-1:0]        id_ex_rs2_value_q; 
    logic [XLEN-1:0]        id_ex_rs2_value_d;
    logic [XLEN-1:0]        id_ex_rd_old_value_q;
    logic [XLEN-1:0]        id_ex_rd_old_value_d;
    logic [XLEN-1:0]        id_ex_imm_i_q; 
    logic [XLEN-1:0]        id_ex_imm_i_d;
    logic [XLEN-1:0]        id_ex_imm_s_q;
    logic [XLEN-1:0]        id_ex_imm_s_d;
    logic [XLEN-1:0]        id_ex_imm_b_q; 
    logic [XLEN-1:0]        id_ex_imm_b_d;
    logic [XLEN-1:0]        id_ex_imm_u_q;
    logic [XLEN-1:0]        id_ex_imm_u_d;
    logic [XLEN-1:0]        id_ex_imm_j_q;
    logic [XLEN-1:0]        id_ex_imm_j_d;

    /* EX */
    logic                   mul_active_q; 
    logic                   mul_active_d;
    logic                   mac_active_q;
    logic                   mac_active_d;
    logic                   ex_stage_stall;
    logic                   branch_redirect; 
    logic                   [XLEN-1:0] branch_target;
    
    /* EX/MEM */
    logic                   ex_mem_valid_q;
    logic                   ex_mem_valid_d;
    logic [4:0]             ex_mem_op_q;
    logic [4:0]             ex_mem_op_d;
    logic [REG_ADDR_W-1:0]  ex_mem_rd_q;
    logic [REG_ADDR_W-1:0]  ex_mem_rd_d;
    logic                   ex_mem_rd_we_q;
    logic                   ex_mem_rd_we_d;
    logic [XLEN-1:0]        ex_mem_result_q;
    logic [XLEN-1:0]        ex_mem_result_d;
    logic [XLEN-1:0]        ex_mem_store_data_q;
    logic [XLEN-1:0]        ex_mem_store_data_d;

    /* MEM/WB */
    logic                   mem_wb_valid_q;
    logic                   mem_wb_valid_d;
    logic [4:0]             mem_wb_op_q;
    logic [4:0]             mem_wb_op_d;
    logic [REG_ADDR_W-1:0]  mem_wb_rd_q;
    logic [REG_ADDR_W-1:0]  mem_wb_rd_d;
    logic                   mem_wb_rd_we_q;
    logic                   mem_wb_rd_we_d;
    logic [XLEN-1:0]        mem_wb_data_q;
    logic [XLEN-1:0]        mem_wb_data_d;

    /* WB & forwarding */
    logic [XLEN-1:0]        mem_stage_wb_data;
    logic                   ex_mem_forward_valid; // Report whether EX/MEM can forward to the EX stage.
    logic                   mem_wb_forward_valid; // Report whether MEM/WB can forward to the EX stage.
    logic                   rf_we; 
    logic [REG_ADDR_W-1:0]  rf_waddr; 
    logic [XLEN-1:0]        rf_wdata;

    logic                   retire_valid;
    logic                   retire_ebreak;
    logic                   retire_add;
    logic                   retire_mul;
    logic                   retire_mac;

    assign pipeline_stall = ex_stage_stall || load_use_hazard;
    assign decode_accept = if_id_valid_q && !pipeline_stall && !branch_redirect && !drain_q && !halt_q;
    assign ebreak_decode_event = decode_accept && dec_legal && dec_is_ebreak;
    assign illegal_decode_event = decode_accept && !dec_legal;
    assign fetch_stop = halt_q || drain_q || ebreak_decode_event || illegal_decode_event;
    assign id_flush = branch_redirect || illegal_decode_event;
    assign pipeline_empty_next = !if_id_valid_d && !id_ex_valid_d && !ex_mem_valid_d && !mem_wb_valid_d;
    assign halt_o = halt_q;
    assign illegal_o = illegal_q;
    assign cycle_count_o = cycle_count_q;
    assign instr_count_o = instr_count_q;
    assign add_count_o = add_count_q;
    assign mul_count_o = mul_count_q;
    assign mac_count_o = mac_count_q;

    if_stage if_stage_inst (
      .fetch_stop_i(fetch_stop),
      .pipeline_stall_i(pipeline_stall), 
      .branch_redirect_i(branch_redirect),
      .id_flush_i(id_flush), 
      .pc_q_i(pc_q),
      .if_id_valid_q_i(if_id_valid_q), 
      .if_id_pc_q_i(if_id_pc_q),
      .if_id_instr_q_i(if_id_instr_q),
      .imem_rdata_i(imem_rdata_i),
      .branch_target_i(branch_target),
      .imem_addr_o(imem_addr_o),
      .pc_d_o(pc_d),
      .if_id_valid_d_o(if_id_valid_d),
      .if_id_pc_d_o(if_id_pc_d),
      .if_id_instr_d_o(if_id_instr_d)
    );

    id_stage id_stage_inst (
      .clk(clk),
      .rst_n(rst_n),
      .halt_i(halt_q),
      .branch_redirect_i(branch_redirect),
      .pipeline_stall_i(pipeline_stall),
      .ex_stage_stall_i(ex_stage_stall),
      .id_flush_i(id_flush), 
      .if_id_valid_q_i(if_id_valid_q),
      .if_id_pc_q_i(if_id_pc_q),
      .if_id_instr_q_i(if_id_instr_q),
      .id_ex_valid_q_i(id_ex_valid_q),
      .id_ex_pc_q_i(id_ex_pc_q),
      .id_ex_op_q_i(id_ex_op_q),
      .id_ex_rd_q_i(id_ex_rd_q),
      .id_ex_rs1_q_i(id_ex_rs1_q),
      .id_ex_rs2_q_i(id_ex_rs2_q),
      .id_ex_uses_rs1_q_i(id_ex_uses_rs1_q),
      .id_ex_uses_rs2_q_i(id_ex_uses_rs2_q),
      .id_ex_uses_rd_old_q_i(id_ex_uses_rd_old_q),
      .id_ex_rd_we_q_i(id_ex_rd_we_q),
      .id_ex_rs1_value_q_i(id_ex_rs1_value_q),
      .id_ex_rs2_value_q_i(id_ex_rs2_value_q),
      .id_ex_rd_old_value_q_i(id_ex_rd_old_value_q),
      .id_ex_imm_i_q_i(id_ex_imm_i_q),
      .id_ex_imm_s_q_i(id_ex_imm_s_q),
      .id_ex_imm_b_q_i(id_ex_imm_b_q),
      .id_ex_imm_u_q_i(id_ex_imm_u_q),
      .id_ex_imm_j_q_i(id_ex_imm_j_q),
      .wb_we_i(rf_we),
      .wb_rd_i(rf_waddr),
      .wb_data_i(rf_wdata),
      .dec_legal_o(dec_legal),
      .dec_is_ebreak_o(dec_is_ebreak),
      .load_use_hazard_o(load_use_hazard),
      .id_ex_valid_d_o(id_ex_valid_d),
      .id_ex_pc_d_o(id_ex_pc_d),
      .id_ex_op_d_o(id_ex_op_d),
      .id_ex_rd_d_o(id_ex_rd_d),
      .id_ex_rs1_d_o(id_ex_rs1_d),
      .id_ex_rs2_d_o(id_ex_rs2_d),
      .id_ex_uses_rs1_d_o(id_ex_uses_rs1_d),
      .id_ex_uses_rs2_d_o(id_ex_uses_rs2_d),
      .id_ex_uses_rd_old_d_o(id_ex_uses_rd_old_d),
      .id_ex_rd_we_d_o(id_ex_rd_we_d),
      .id_ex_rs1_value_d_o(id_ex_rs1_value_d),
      .id_ex_rs2_value_d_o(id_ex_rs2_value_d),
      .id_ex_rd_old_value_d_o(id_ex_rd_old_value_d),
      .id_ex_imm_i_d_o(id_ex_imm_i_d),
      .id_ex_imm_s_d_o(id_ex_imm_s_d),
      .id_ex_imm_b_d_o(id_ex_imm_b_d),
      .id_ex_imm_u_d_o(id_ex_imm_u_d),
      .id_ex_imm_j_d_o(id_ex_imm_j_d),
      .debug_illegal_instr_o(debug_illegal_instr_o),
      .debug_x3_o(debug_x3_o),
      .debug_x5_o(debug_x5_o),
      .debug_x6_o(debug_x6_o),
      .debug_x31_o(debug_x31_o)
    );

    ex_stage ex_stage_inst (
      .clk(clk),
      .rst_n(rst_n),
      .halt_i(halt_q),
      .id_ex_valid_q_i(id_ex_valid_q),
      .id_ex_pc_q_i(id_ex_pc_q),
      .id_ex_op_q_i(id_ex_op_q),
      .id_ex_rd_q_i(id_ex_rd_q),
      .id_ex_rs1_q_i(id_ex_rs1_q),
      .id_ex_rs2_q_i(id_ex_rs2_q),
      .id_ex_uses_rs1_q_i(id_ex_uses_rs1_q),
      .id_ex_uses_rs2_q_i(id_ex_uses_rs2_q),
      .id_ex_uses_rd_old_q_i(id_ex_uses_rd_old_q),
      .id_ex_rd_we_q_i(id_ex_rd_we_q), 
      .id_ex_rs1_value_q_i(id_ex_rs1_value_q),
      .id_ex_rs2_value_q_i(id_ex_rs2_value_q),
      .id_ex_rd_old_value_q_i(id_ex_rd_old_value_q),
      .id_ex_imm_i_q_i(id_ex_imm_i_q),
      .id_ex_imm_s_q_i(id_ex_imm_s_q),
      .id_ex_imm_b_q_i(id_ex_imm_b_q),
      .id_ex_imm_u_q_i(id_ex_imm_u_q),
      .id_ex_imm_j_q_i(id_ex_imm_j_q),
      .ex_mem_forward_valid_i(ex_mem_forward_valid),
      .ex_mem_forward_rd_i(ex_mem_rd_q),
      .ex_mem_forward_data_i(mem_stage_wb_data),
      .mem_wb_forward_valid_i(mem_wb_forward_valid),
      .mem_wb_forward_rd_i(mem_wb_rd_q),
      .mem_wb_forward_data_i(mem_wb_data_q),
      .mul_active_q_i(mul_active_q),
      .mac_active_q_i(mac_active_q),
      .ex_stage_stall_o(ex_stage_stall),
      .branch_redirect_o(branch_redirect),
      .branch_target_o(branch_target),
      .ex_mem_valid_d_o(ex_mem_valid_d),
      .ex_mem_op_d_o(ex_mem_op_d),
      .ex_mem_rd_d_o(ex_mem_rd_d),
      .ex_mem_rd_we_d_o(ex_mem_rd_we_d),
      .ex_mem_result_d_o(ex_mem_result_d),
      .ex_mem_store_data_d_o(ex_mem_store_data_d),
      .mul_active_d_o(mul_active_d),
      .mac_active_d_o(mac_active_d)
    );

    mem_stage mem_stage_inst (
      .halt_i(halt_q), 
      .ex_mem_valid_q_i(ex_mem_valid_q),
      .ex_mem_op_q_i(ex_mem_op_q),
      .ex_mem_rd_q_i(ex_mem_rd_q),
      .ex_mem_rd_we_q_i(ex_mem_rd_we_q),
      .ex_mem_result_q_i(ex_mem_result_q),
      .ex_mem_store_data_q_i(ex_mem_store_data_q),
      .dmem_rdata_i(dmem_rdata_i),
      .dmem_addr_o(dmem_addr_o),
      .dmem_wdata_o(dmem_wdata_o),
      .dmem_we_o(dmem_we_o),
      .mem_stage_wb_data_o(mem_stage_wb_data),
      .ex_mem_forward_valid_o(ex_mem_forward_valid),
      .mem_wb_valid_d_o(mem_wb_valid_d),
      .mem_wb_op_d_o(mem_wb_op_d),
      .mem_wb_rd_d_o(mem_wb_rd_d),
      .mem_wb_rd_we_d_o(mem_wb_rd_we_d),
      .mem_wb_data_d_o(mem_wb_data_d)
    );

    wb_stage wb_stage_inst (
      .halt_i(halt_q),
      .mem_wb_valid_q_i(mem_wb_valid_q),
      .mem_wb_op_q_i(mem_wb_op_q),
      .mem_wb_rd_q_i(mem_wb_rd_q),
      .mem_wb_rd_we_q_i(mem_wb_rd_we_q),
      .mem_wb_data_q_i(mem_wb_data_q),
      .rf_we_o(rf_we),
      .rf_waddr_o(rf_waddr), 
      .rf_wdata_o(rf_wdata),
      .mem_wb_forward_valid_o(mem_wb_forward_valid),
      .retire_valid_o(retire_valid),
      .retire_ebreak_o(retire_ebreak),
      .retire_add_o(retire_add),
      .retire_mul_o(retire_mul),
      .retire_mac_o(retire_mac)
    );

    always_comb begin
        halt_d = halt_q;
        drain_d = drain_q;
        illegal_d = illegal_q;
        cycle_count_d = halt_q ? cycle_count_q : (cycle_count_q + 32'd1);
        instr_count_d = (!halt_q && retire_valid) ? (instr_count_q + 32'd1) : instr_count_q;
        add_count_d = (!halt_q && retire_add) ? (add_count_q + 32'd1) : add_count_q;
        mul_count_d = (!halt_q && retire_mul) ? (mul_count_q + 32'd1) : mul_count_q;
        mac_count_d = (!halt_q && retire_mac) ? (mac_count_q + 32'd1) : mac_count_q;

        if (ebreak_decode_event) begin
            drain_d = 1'b1;
        end

        /* Stop on illegal decode once the instruction can be consumed. */ 
        if (!halt_q && if_id_valid_q && !dec_legal && !pipeline_stall) begin
            halt_d = 1'b1;
            illegal_d = 1'b1;
        end

        /* Finish only when the stop reason is resolved and every next-state pipeline valid bit is clear. */
        if (!halt_q && (retire_ebreak || illegal_d) && drain_d && pipeline_empty_next) begin
            halt_d = 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            halt_q <= 1'b0;
            drain_q <= 1'b0;
            illegal_q <= 1'b0;
            pc_q <= RESET_PC;
            cycle_count_q <= '0;
            instr_count_q <= '0;
            add_count_q <= '0;
            mul_count_q <= '0;
            mac_count_q <= '0;
            if_id_valid_q <= 1'b0;
            if_id_pc_q <= '0;
            if_id_instr_q <= '0;
            id_ex_valid_q <= 1'b0;
            id_ex_pc_q <= '0;
            id_ex_op_q <= OP_INVALID;
            id_ex_rd_q <= '0;
            id_ex_rs1_q <= '0;
            id_ex_rs2_q <= '0;
            id_ex_uses_rs1_q <= 1'b0;
            id_ex_uses_rs2_q <= 1'b0;
            id_ex_uses_rd_old_q <= 1'b0;
            id_ex_rd_we_q <= 1'b0;
            id_ex_rs1_value_q <= '0;
            id_ex_rs2_value_q <= '0;
            id_ex_rd_old_value_q <= '0;
            id_ex_imm_i_q <= '0;
            id_ex_imm_s_q <= '0;
            id_ex_imm_b_q <= '0;
            id_ex_imm_u_q <= '0;
            id_ex_imm_j_q <= '0;
            ex_mem_valid_q <= 1'b0;
            ex_mem_op_q <= OP_INVALID;
            ex_mem_rd_q <= '0;
            ex_mem_rd_we_q <= '0;
            ex_mem_result_q <= '0;
            ex_mem_store_data_q <= '0;
            mem_wb_valid_q <= 1'b0;
            mem_wb_op_q <= OP_INVALID;
            mem_wb_rd_q <= '0;
            mem_wb_rd_we_q <= 1'b0;
            mem_wb_data_q <= '0;
            mul_active_q <= 1'b0;
            mac_active_q <= 1'b0;
        end else begin
            halt_q <= halt_d;
            drain_q <= drain_d;
            illegal_q <= illegal_d;
            pc_q <= pc_d;
            cycle_count_q <= cycle_count_d;
            instr_count_q <= instr_count_d;
            add_count_q <= add_count_d;
            mul_count_q <= mul_count_d;
            mac_count_q <= mac_count_d;
            if_id_valid_q <= if_id_valid_d;
            if_id_pc_q <= if_id_pc_d;
            if_id_instr_q <= if_id_instr_d;
            id_ex_valid_q <= id_ex_valid_d;
            id_ex_pc_q <= id_ex_pc_d;
            id_ex_op_q <= id_ex_op_d;
            id_ex_rd_q <= id_ex_rd_d;
            id_ex_rs1_q <= id_ex_rs1_d;
            id_ex_rs2_q <= id_ex_rs2_d;
            id_ex_uses_rs1_q <= id_ex_uses_rs1_d;
            id_ex_uses_rs2_q <= id_ex_uses_rs2_d;
            id_ex_uses_rd_old_q <= id_ex_uses_rd_old_d;
            id_ex_rd_we_q <= id_ex_rd_we_d;
            id_ex_rs1_value_q <= id_ex_rs1_value_d;
            id_ex_rs2_value_q <= id_ex_rs2_value_d;
            id_ex_rd_old_value_q <= id_ex_rd_old_value_d;
            id_ex_imm_i_q <= id_ex_imm_i_d;
            id_ex_imm_s_q <= id_ex_imm_s_d;
            id_ex_imm_b_q <= id_ex_imm_b_d;
            id_ex_imm_u_q <= id_ex_imm_u_d;
            id_ex_imm_j_q <= id_ex_imm_j_d;
            ex_mem_valid_q <= ex_mem_valid_d;
            ex_mem_op_q <= ex_mem_op_d;
            ex_mem_rd_q <= ex_mem_rd_d;
            ex_mem_rd_we_q <= ex_mem_rd_we_d;
            ex_mem_result_q <= ex_mem_result_d;
            ex_mem_store_data_q <= ex_mem_store_data_d;
            mem_wb_valid_q <= mem_wb_valid_d;
            mem_wb_op_q <= mem_wb_op_d;
            mem_wb_rd_q <= mem_wb_rd_d;
            mem_wb_rd_we_q <= mem_wb_rd_we_d;
            mem_wb_data_q <= mem_wb_data_d;
            mul_active_q <= mul_active_d;
            mac_active_q <= mac_active_d;
        end
    end

endmodule : rv32_core
