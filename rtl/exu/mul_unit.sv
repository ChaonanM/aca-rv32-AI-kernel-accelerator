module mul_unit import rv32_pkg::*;(
    input  logic                clk,
    input  logic                rst_n,
    input  logic                start_i,
    input  logic [XLEN-1:0]     lhs_i,
    input  logic [XLEN-1:0]     rhs_i,
    
    output logic                done_o,
    output logic [XLEN-1:0]     result_o
);

    localparam int unsigned MUL_COUNT_W = $clog2(MUL_LATENCY+1);
    localparam logic [MUL_COUNT_W-1:0] MUL_LATENCY_COUNT = MUL_COUNT_W'(MUL_LATENCY);   // Cast the latency value to the counter width.
    localparam logic [MUL_COUNT_W-1:0] MUL_COUNT_ONE = {{(MUL_COUNT_W-1){1'b0}}, 1'b1}; // Define a counter-width constant one.
    logic [MUL_COUNT_W-1:0] latency_left_q;
    logic [XLEN-1:0] result_q;
    logic [XLEN*2-1:0] lhs_extend;
    logic [XLEN*2-1:0] rhs_extend;
    logic [XLEN*2-1:0] product;

    assign lhs_extend = {32'b0, lhs_i};
    assign rhs_extend = {32'b0, rhs_i};
    assign product = lhs_extend * rhs_extend;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latency_left_q <= '0;
            result_q <= '0;
        end else if (start_i && (latency_left_q == '0)) begin
            latency_left_q <= MUL_LATENCY_COUNT;
            result_q <= product[31:0];
        end else if (latency_left_q != '0) begin
            latency_left_q <= latency_left_q - MUL_COUNT_ONE;
        end        
    end

    assign done_o = (latency_left_q == MUL_COUNT_ONE);
    assign result_o = result_q;

endmodule : mul_unit
