module mac_unit import rv32_pkg::*; (
    input  logic            clk,
    input  logic            rst_n,
    input  logic            start_i,
    input  logic [XLEN-1:0] lhs_i,
    input  logic [XLEN-1:0] rhs_i,
    input  logic [XLEN-1:0] accumulator_i,

    output logic            done_o,
    output logic [XLEN-1:0] result_o
);

    localparam int unsigned MAC_COUNT_W = $clog2(MAC_LATENCY+1);
    localparam logic [MAC_COUNT_W-1:0] MAC_LATENCY_COUNT = MAC_COUNT_W'(MAC_LATENCY);
    localparam logic [MAC_COUNT_W-1:0] MAC_COUNT_ONE = {{(MAC_COUNT_W-1){1'b0}}, 1'b1};
    logic [MAC_COUNT_W-1:0] latency_left_q;
    logic [XLEN-1:0] result_q;
    logic [XLEN*2-1:0] lhs_extend;
    logic [XLEN*2-1:0] rhs_extend;
    logic [XLEN*2-1:0] product_comb;
    logic [XLEN:0]   sum_comb;

    assign lhs_extend = {{XLEN{1'b0}}, lhs_i};
    assign rhs_extend = {{XLEN{1'b0}}, rhs_i};
    assign product_comb = lhs_extend * rhs_extend;
    assign sum_comb = {1'b0, accumulator_i} + {1'b0, product_comb[XLEN-1:0]};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latency_left_q <= '0;
            result_q <= '0;
        end else if (start_i && (latency_left_q == '0)) begin
            latency_left_q <= MAC_LATENCY_COUNT;
            result_q <= sum_comb[XLEN-1:0];
        end else if (latency_left_q != '0) begin
            latency_left_q <= latency_left_q - MAC_COUNT_ONE;
        end
    end

    assign done_o = (latency_left_q == MAC_COUNT_ONE);
    assign result_o = result_q;

endmodule :mac_unit
