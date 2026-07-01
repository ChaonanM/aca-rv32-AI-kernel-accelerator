#include <cstdint>
#include <iostream>

#include "Valu.h"

namespace {

constexpr std::uint8_t kAluAdd = 0; // Match ALU_ADD from rv32_pkg.sv.
constexpr std::uint8_t kAluSub = 1;
constexpr std::uint8_t kAluPassB = 2;

    bool expect_equal(Valu& dut, std::uint8_t op, std::uint32_t lhs, std::uint32_t rhs, std::uint32_t expected, const char* name) {
        dut.alu_op_i = op;
        dut.lhs_i = lhs;
        dut.rhs_i = rhs;
        dut.eval();
        if (dut.result_o != expected) {
            std::cerr << "ALU FAIL: " << name << " expected " << expected << " but got " << dut.result_o << '\n';
            return false;
        }
        return true;
    }
}

int main() {
    Valu dut;

    bool correct = true;
    correct = expect_equal(dut, kAluAdd, 19u, 23u, 42u, "ADD") && correct;
    correct = expect_equal(dut, kAluSub, 50u, 8u, 42u, "SUB") && correct;
    correct = expect_equal(dut, kAluPassB, 0xFFFF'FFFFu, 0x1234'5000u, 0x1234'5000u, "PASS_B") && correct;
    correct = expect_equal(dut, kAluAdd, 0xFFFF'FFFFu, 1u, 0u, "32-bit wraparound") && correct;
    correct = expect_equal(dut, 7u, 1u, 2u, 0u, "invalid operation default") && correct;
    dut.final();
    if (!correct)
        return 1;
    std::cout << "UNIT PASS: ALU ADD, SUB, PASS_B, wraparound, and invalid default\n";
    return 0;
}