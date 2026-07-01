#include <cstdint>
#include <iostream>

#include "Vbranch_unit.h"

namespace {

constexpr std::uint8_t kBranchNone = 0; // Match BR_NONE from rv32_pkg.sv.
constexpr std::uint8_t kBranchEq = 1;
constexpr std::uint8_t kBranchNe = 2;
constexpr std::uint8_t kBranchLt = 3;

    bool expect_equal(Vbranch_unit& dut, std::uint8_t op, std::uint32_t lhs, std::uint32_t rhs, bool expected, const char* name) {
        dut.branch_op_i = op;
        dut.lhs_i = lhs;
        dut.rhs_i = rhs;
        dut.eval();
        if (static_cast<bool>(dut.taken_o) != expected) {
            std::cerr << "BRANCH FAIL: " << name << " expected " << expected << " but got " << static_cast<bool>(dut.taken_o) << '\n';
            return false;
        }
        return true;
    }
}

int main() {
    Vbranch_unit dut;

    bool correct = true;
    correct = expect_equal(dut, kBranchEq, 42u, 42u, true, "BEQ equal") && correct;
    correct = expect_equal(dut, kBranchEq, 42u, 41u, false, "BEQ unequal") && correct;
    correct = expect_equal(dut, kBranchNe, 42u, 41u, true, "BNE unequal") && correct;
    correct = expect_equal(dut, kBranchNe, 42u, 42u, false, "BNE equal") && correct;
    correct = expect_equal(dut, kBranchLt, 0xFFFF'FFFFu, 1u, true, "BLT negative less than positive") && correct;
    correct = expect_equal(dut, kBranchLt, 1u, 0xFFFF'FFFFu, false, "BLT positive not less than negative") && correct;
    correct = expect_equal(dut, kBranchNone, 0u, 0u, false, "non-branch default") && correct;
    dut.final();
    if (!correct)
        return 1;
    std::cout << "UNIT PASS: branch BEQ, BNE, signed BLT, and non-branch default\n";
    return 0;
}