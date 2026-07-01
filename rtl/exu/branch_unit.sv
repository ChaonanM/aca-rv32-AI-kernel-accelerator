module branch_unit import rv32_pkg::*;(
    input  logic [1:0]      branch_op_i,
    input  logic [XLEN-1:0] lhs_i,
    input  logic [XLEN-1:0] rhs_i,
    output logic            taken_o
);

    always_comb begin
        unique case (branch_op_i)
            BR_EQ: taken_o = (lhs_i == rhs_i);
            BR_NE: taken_o = (lhs_i != rhs_i);
            BR_LT: taken_o = ($signed(lhs_i) < $signed(rhs_i));
            default: taken_o = 1'b0;
        endcase
    end

endmodule : branch_unit
