module alu import rv32_pkg::*;(
    input  logic [2:0]      alu_op_i,
    input  logic [XLEN-1:0] lhs_i,
    input  logic [XLEN-1:0] rhs_i,
    output logic [XLEN-1:0] result_o
);

    always_comb begin
        result_o = '0;
        unique case (alu_op_i)
            ALU_ADD: result_o = lhs_i + rhs_i;
            ALU_SUB: result_o = lhs_i - rhs_i;
            ALU_PASS_B: result_o = rhs_i;           // Forward operand B for LUI-style constant movement.
            default: ;
        endcase
    end

endmodule : alu
