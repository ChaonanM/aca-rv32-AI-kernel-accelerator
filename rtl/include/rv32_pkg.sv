`timescale 1ns/1ps

package rv32_pkg;

    localparam int unsigned XLEN = 32;
    localparam logic [XLEN-1:0] RESET_PC = 32'h0000_0000;

    localparam int unsigned REG_ADDR_W = 5;
    localparam int unsigned REG_COUNT = 32;
    
    localparam int unsigned MEM_WORDS = 256;
    localparam int unsigned MEM_INDEX_BITS = 8;
    localparam int unsigned MEM_ADDR_MSB = 9;
    
    localparam int unsigned MUL_LATENCY = 3;
    localparam int unsigned MAC_LATENCY = 3;

    /* OPCODE */
    localparam logic [6:0] OPCODE_LOAD      = 7'b0000011;
    localparam logic [6:0] OPCODE_OP_IMM    = 7'b0010011;
    localparam logic [6:0] OPCODE_STORE     = 7'b0100011;
    localparam logic [6:0] OPCODE_OP        = 7'b0110011;
    localparam logic [6:0] OPCODE_LUI       = 7'b0110111;
    localparam logic [6:0] OPCODE_BRANCH    = 7'b1100011;
    localparam logic [6:0] OPCODE_JAL       = 7'b1101111;
    localparam logic [6:0] OPCODE_SYSTEM    = 7'b1110011;  // Define the opcode used by EBREAK.
    localparam logic [6:0] OPCODE_CUSTOM_0  = 7'b0001011;

    /* FUNCT3 */
    localparam logic [2:0] FUNCT3_ADD_SUB_MUL   = 3'b000;
    localparam logic [2:0] FUNCT3_ADDI          = 3'b000;
    localparam logic [2:0] FUNCT3_LW_SW         = 3'b010;
    localparam logic [2:0] FUNCT3_BEQ           = 3'b000;
    localparam logic [2:0] FUNCT3_BNE           = 3'b001;
    localparam logic [2:0] FUNCT3_BLT           = 3'b100;
    localparam logic [2:0] FUNCT3_MAC           = 3'b000;

    /* FUNCT7 */
    localparam logic [6:0] FUNCT7_ADD = 7'b0000000;
    localparam logic [6:0] FUNCT7_SUB = 7'b0100000;
    localparam logic [6:0] FUNCT7_MUL = 7'b0000001;
    localparam logic [6:0] FUNCT7_MAC = 7'b0000001;
    
    localparam logic [4:0] OP_INVALID = 5'd0;
    localparam logic [4:0] OP_ADD = 5'd1;
    localparam logic [4:0] OP_SUB = 5'd2;
    localparam logic [4:0] OP_ADDI = 5'd3;
    localparam logic [4:0] OP_MUL = 5'd4;
    localparam logic [4:0] OP_LW = 5'd5;
    localparam logic [4:0] OP_SW = 5'd6;
    localparam logic [4:0] OP_BEQ = 5'd7;
    localparam logic [4:0] OP_BNE = 5'd8;
    localparam logic [4:0] OP_BLT = 5'd9;
    localparam logic [4:0] OP_JAL = 5'd10;
    localparam logic [4:0] OP_LUI = 5'd11;
    localparam logic [4:0] OP_EBREAK = 5'd12;
    localparam logic [4:0] OP_MAC = 5'd13;
    
    localparam logic [2:0] ALU_ADD = 3'd0; 
    localparam logic [2:0] ALU_SUB = 3'd1;
    localparam logic [2:0] ALU_PASS_B = 3'd2;

    localparam logic [1:0] BR_NONE = 2'd0; 
    localparam logic [1:0] BR_EQ = 2'd1; 
    localparam logic [1:0] BR_NE = 2'd2; 
    localparam logic [1:0] BR_LT = 2'd3;
endpackage : rv32_pkg
