#include <cstdint>
#include <iostream>

#include "Vdecoder.h"

namespace {

    struct DecodeCase {
        const char* name;
        std::uint32_t instruction;
        std::uint8_t operation;
        bool legal;
        bool write_en;
        bool uses_rs1;
        bool uses_rs2;
        bool uses_rd_old;
    };

    bool check_case(Vdecoder& dut, const DecodeCase& test) {
        dut.instr_i = test.instruction;
        dut.eval();
        const bool matches = (static_cast<bool>(dut.instr_legal_o) == test.legal) && (dut.op_o == test.operation) && (static_cast<bool>(dut.rd_we_o) == test.write_en) && (static_cast<bool>(dut.uses_rs1_o) == test.uses_rs1) && (static_cast<bool>(dut.uses_rs2_o) == test.uses_rs2) && (static_cast<bool>(dut.uses_rd_old_o) == test.uses_rd_old);
        if (!matches) {
            std::cerr << "DECODER FAIL: " << test.name << " legal=" << static_cast<bool>(dut.instr_legal_o) << " op=" << static_cast<unsigned>(dut.op_o) << " rd_we=" << static_cast<bool>(dut.rd_we_o) << " rs1=" << static_cast<bool>(dut.uses_rs1_o) << " rs2=" << static_cast<bool>(dut.uses_rs2_o) << " rd_old=" << static_cast<bool>(dut.uses_rd_old_o) << '\n';
            return false;
        }
        return true;
    }
}

int main() {
    Vdecoder dut;
    const DecodeCase cases[] = { // Define coverage for every currently supported internal operation plus one illegal word.
        {"ADD", 0x0020'81B3u, 1u, true, true, true, true, false},
        {"SUB", 0x4020'81B3u, 2u, true, true, true, true, false},
        {"ADDI", 0xFFF0'8193u, 3u, true, true, true, false, false},
        {"MUL", 0x0220'81B3u, 4u, true, true, true, true, false},
        {"LW", 0x0040'A183u, 5u, true, true, true, false, false},
        {"SW", 0x0020'A423u, 6u, true, false, true, true, false},
        {"BEQ", 0x0020'8463u, 7u, true, false, true, true, false},
        {"BNE", 0x0020'9463u, 8u, true, false, true, true, false},
        {"BLT", 0x0020'C463u, 9u, true, false, true, true, false},
        {"JAL", 0x0080'01EFu, 10u, true, true, false, false, false},
        {"LUI", 0x1234'51B7u, 11u, true, true, false, false, false},
        {"EBREAK", 0x0010'0073u, 12u, true, false, false, false, false},
        {"MAC", 0x0220'818Bu, 13u, true, true, true, true, true},
        {"illegal zero", 0x0000'0000u, 0u, false, false, false, false, false},
    };

    bool correct = true;
    for (const DecodeCase& test : cases) {
        correct = check_case(dut, test) && correct;
    }
    
    dut.instr_i = 0x0020'81B3u; // Re-drive ADD to verify fixed RISC-V register-field extraction.
    dut.eval();
    if ((dut.rd_o != 3u) || (dut.rs1_o != 1u) || (dut.rs2_o != 2u)) {
        std::cerr << "DECODER FAIL: ADD register fields expected rd=3 rs1=1 rs2=2\n";
        correct = false;
    }

    dut.final();
    if (!correct)
        return 1;
    std::cout << "UNIT PASS: decoder complete baseline subset, metadata, fields, and illegal default\n";
    return 0;
}