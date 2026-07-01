module decoder import rv32_pkg::*;(
    input  logic [XLEN-1:0]         instr_i,
    output logic                    instr_legal_o,
    output logic [XLEN-1:0]         debug_illegal_instr_o,
    output logic [4:0]              op_o,
    output logic [REG_ADDR_W-1:0]   rs1_o,
    output logic [REG_ADDR_W-1:0]   rs2_o,
    output logic [REG_ADDR_W-1:0]   rd_o,
    output logic                    rd_we_o,
    output logic                    uses_rs1_o,
    output logic                    uses_rs2_o,
    output logic                    uses_rd_old_o
);

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr_i[6:0];
    assign funct3 = instr_i[14:12];
    assign funct7 = instr_i[31:25];
    assign rd_o = instr_i[11:7];
    assign rs1_o = instr_i[19:15];
    assign rs2_o = instr_i[24:20];
    assign debug_illegal_instr_o = (instr_legal_o == 1'b0) ? instr_i : 32'hFFFF_FFFF;
    
    always_comb begin
        instr_legal_o = 1'b0;
        op_o = OP_INVALID;          // Default the internal operation to invalid.
        rd_we_o = 1'b0;
        uses_rs1_o = 1'b0;
        uses_rs2_o = 1'b0;
        uses_rd_old_o = 1'b0;
        unique case (opcode)
            OPCODE_OP: begin
                uses_rs1_o = 1'b1;
                uses_rs2_o = 1'b1;
                rd_we_o = 1'b1;
                if ((funct3 == FUNCT3_ADD_SUB_MUL) && (funct7 == FUNCT7_ADD)) begin
                    instr_legal_o = 1'b1;
                    op_o = OP_ADD;
                end else if ((funct3 == FUNCT3_ADD_SUB_MUL) && (funct7 == FUNCT7_SUB)) begin
                    instr_legal_o = 1'b1;
                    op_o = OP_SUB;
                end else if ((funct3 == FUNCT3_ADD_SUB_MUL) && (funct7 == FUNCT7_MUL)) begin
                    instr_legal_o = 1'b1;
                    op_o = OP_MUL;
                end else begin
                    rd_we_o = 1'b0;
                end
            end
            OPCODE_OP_IMM: begin
                if (funct3 == FUNCT3_ADDI) begin
                    instr_legal_o = 1'b1;
                    op_o = OP_ADDI;
                    uses_rs1_o = 1'b1;
                    rd_we_o = 1'b1;
                end
            end
            OPCODE_LOAD: begin
                if (funct3 == FUNCT3_LW_SW) begin
                    instr_legal_o = 1'b1;
                    op_o = OP_LW;
                    uses_rs1_o = 1'b1;
                    rd_we_o = 1'b1;
                end
            end
            OPCODE_STORE: begin
                if (funct3 == FUNCT3_LW_SW) begin
                    instr_legal_o = 1'b1;
                    op_o = OP_SW;
                    uses_rs1_o = 1'b1;
                    uses_rs2_o = 1'b1;
                end
            end
            OPCODE_BRANCH: begin
                uses_rs1_o = 1'b1;
                uses_rs2_o = 1'b1;
                if (funct3 == FUNCT3_BEQ) begin
                    instr_legal_o = 1'b1;
                    op_o = OP_BEQ;
                end else if (funct3 == FUNCT3_BNE) begin
                    instr_legal_o = 1'b1;
                    op_o = OP_BNE;
                end else if (funct3 == FUNCT3_BLT) begin
                    instr_legal_o = 1'b1;
                    op_o = OP_BLT;
                end
            end
            OPCODE_JAL: begin
                instr_legal_o = 1'b1;
                op_o = OP_JAL;
                rd_we_o = 1'b1;
            end
            OPCODE_LUI: begin
                instr_legal_o = 1'b1;
                op_o = OP_LUI;
                rd_we_o = 1'b1;
            end
            OPCODE_SYSTEM: begin
                if (instr_i == 32'h0010_0073) begin
                    instr_legal_o = 1'b1;
                    op_o = OP_EBREAK;
                end
            end
            OPCODE_CUSTOM_0: begin
                if ((funct3 == FUNCT3_MAC) && (funct7 == FUNCT7_MAC)) begin
                    instr_legal_o = 1'b1;
                    op_o = OP_MAC;
                    rd_we_o = 1'b1;
                    uses_rs1_o = 1'b1;
                    uses_rs2_o = 1'b1;
                    uses_rd_old_o = 1'b1;
                end
            end
            default: ;    
        endcase
    end

endmodule : decoder
