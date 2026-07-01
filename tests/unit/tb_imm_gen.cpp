#include <cstdint>
#include <iostream>

#include "Vimm_gen.h"

namespace {

    bool expect_equal(const char* name, std::uint32_t actual, std::uint32_t expected) {
        if (actual != expected) {
            std::cerr << "IMM FAIL: " << name << " expected " << std::hex << expected << " but got 0x" << actual << '\n';
            return false;
        }
        return true;
    }
}

int main() {
    Vimm_gen dut;
    
    bool correct = true;
    dut.instr_i = 0xFFC0'0093u;  // Drive ADDI x1,x0,-4 to test signed I-immediate extraction.
    dut.eval();
    correct = expect_equal("I immediate -4", dut.imm_i_o, 0xFFFF'FFFCu) && correct;
    dut.instr_i = 0xFE21'AC23u; // Drive SW x2,-8(x3) to test split S-immediate reconstruction.
    dut.eval();
    correct = expect_equal("S immediate -8", dut.imm_s_o, 0xFFFF'FFF8u) && correct; 
    dut.instr_i = 0xFE20'C8E3u; // Drive BLT x1,x2,-16 to test B-immediate bit ordering.
    dut.eval(); 
    correct = expect_equal("B immediate -16", dut.imm_b_o, 0xFFFF'FFF0u) && correct;
    dut.instr_i = 0x1234'51B7u; // Drive LUI x3,0x12345 to test U-immediate placement.
    dut.eval(); 
    correct = expect_equal("U immediate", dut.imm_u_o, 0x1234'5000u) && correct; 
    dut.instr_i = 0x0010'00EFu; // Drive JAL x1,2048 to test J-immediate bit ordering.
    dut.eval();
    correct = expect_equal("J immediate 2048", dut.imm_j_o, 0x0000'0800u) && correct;
    dut.final();
    if (!correct)
        return 1;
    std::cout << "UNIT PASS: immediate I, S, B, U, and J reconstruction\n";
    return 0;
}