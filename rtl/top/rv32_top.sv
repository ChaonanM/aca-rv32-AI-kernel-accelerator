module rv32_top import rv32_pkg::*;(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            imem_we_i,
    input  logic [MEM_INDEX_BITS-1:0]       imem_windex_i,
    input  logic [XLEN-1:0]                 imem_wdata_i,
    input  logic                            dmem_we_i,
    input  logic [MEM_INDEX_BITS-1:0]       dmem_windex_i,
    input  logic [XLEN-1:0]                 dmem_wdata_i,
    input  logic [MEM_INDEX_BITS-1:0]       debug_dmem_index_i,
    output logic                            done_o,
    output logic                            illegal_o,
    output logic [XLEN-1:0]                 cycle_count_o,
    output logic [XLEN-1:0]                 instr_count_o,
    output logic [XLEN-1:0]                 add_count_o,
    output logic [XLEN-1:0]                 mul_count_o,
    output logic [XLEN-1:0]                 mac_count_o,
    output logic [XLEN-1:0]                 debug_illegal_instr,
    output logic [XLEN-1:0]                 debug_x3_o,             // Expose x3 for testbench.
    output logic [XLEN-1:0]                 debug_x5_o,             // Expose x5 for testbench.
    output logic [XLEN-1:0]                 debug_x6_o,             // Expose x6 for testbench.
    output logic [XLEN-1:0]                 debug_x31_o,            // Expose x31 for testbench.
    output logic [XLEN-1:0]                 debug_dmem_data_o
);

    logic [XLEN-1:0] imem_q [MEM_WORDS-1:0];
    logic [XLEN-1:0] dmem_q [MEM_WORDS-1:0];
    logic [XLEN-1:0] imem_addr;
    logic [XLEN-1:0] imem_rdata;
    logic [XLEN-1:0] dmem_addr;
    logic [XLEN-1:0] dmem_rdata;
    logic [XLEN-1:0] dmem_wdata;
    logic dmem_we;
    int unsigned init_idx;

    initial begin
        for (init_idx = 0; init_idx < MEM_WORDS; init_idx = init_idx + 1) begin
            imem_q[init_idx] = '0;
            dmem_q[init_idx] = '0;
        end
    end
    
    always_ff @(posedge clk) begin
        if (imem_we_i) begin
            imem_q[imem_windex_i] <= imem_wdata_i;
        end 
        if (dmem_we_i) begin
            dmem_q[dmem_windex_i] <= dmem_wdata_i;
        end else if (dmem_we) begin
            dmem_q[dmem_addr[MEM_ADDR_MSB:2]] <= dmem_wdata;
        end
    end

    assign imem_rdata = imem_q[imem_addr[MEM_ADDR_MSB:2]];
    assign dmem_rdata = dmem_q[dmem_addr[MEM_ADDR_MSB:2]];
    assign debug_dmem_data_o = dmem_q[debug_dmem_index_i];

    rv32_core rv32_core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr_o(imem_addr),
        .imem_rdata_i(imem_rdata),
        .dmem_addr_o(dmem_addr),
        .dmem_wdata_o(dmem_wdata),
        .dmem_we_o(dmem_we),
        .dmem_rdata_i(dmem_rdata),
        .halt_o(done_o),
        .illegal_o(illegal_o),
        .cycle_count_o(cycle_count_o),
        .instr_count_o(instr_count_o),
        .add_count_o(add_count_o),
        .mul_count_o(mul_count_o),
        .mac_count_o(mac_count_o),
        .debug_illegal_instr_o(debug_illegal_instr),
        .debug_x3_o(debug_x3_o),
        .debug_x5_o(debug_x5_o),
        .debug_x6_o(debug_x6_o),
        .debug_x31_o(debug_x31_o)
    );
    
endmodule : rv32_top
