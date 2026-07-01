#include <iostream>
#include <cstdint>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "Vmac_unit.h"

namespace {

    void tick(Vmac_unit& dut) {
        dut.clk = 0;
        dut.eval();
        dut.clk = 1;
        dut.eval();
    }

    bool expect_equal(Vmac_unit& dut, const char* name, std::uint32_t lhs, std::uint32_t rhs, std::uint32_t accumulator, std::uint32_t expected) {
        dut.lhs_i = lhs;
        dut.rhs_i = rhs;
        dut.accumulator_i = accumulator;
        dut.start_i = 1;
        tick(dut);
        bool is_done = false;
        for (std::uint32_t cycle = 0; cycle < 8u; ++cycle) {
            if (dut.done_o) {
                is_done = true;
                break;
            }
            tick(dut);
        }
        if (!is_done || (dut.result_o != expected)) {
            std::cerr << "MAC_UNIT FAIL: " << name << " done=" << is_done << " expected=0x " << std::hex << expected << " but got 0x" << std::hex << dut.result_o << '\n';
            return false;
        }
        tick(dut);
        return true;
    } 
}
    


int main(int argc, char** argv) {
    Vmac_unit dut;
    dut.clk = 0;
    dut.rst_n = 0;
    dut.start_i = 0;
    dut.lhs_i = 0;
    dut.rhs_i = 0;
    dut.accumulator_i = 0;
    tick(dut);

    dut.rst_n = 1;
    bool correct = true;
    correct = expect_equal(dut, "single", 2u, 4u, 10u, 18u) && correct; 
    correct = expect_equal(dut, "first consecutive", 2u, 4u, 0u, 8u) && correct;
    correct = expect_equal(dut, "second consecutive", 3u, 5u, 8u, 23u) && correct;
    correct = expect_equal(dut, "negative wrap", 0xFFFF'FFFEu, 4u, 1u, 0xFFFF'FFF9u) && correct;
    dut.final();
    if (!correct) {
        return 1;
    }
    std::cout << "UNIT PASS: mac_unit handshake, explicit accumulator, consecutive requests, and wraparound wave=build/waves/mac_unit.vcd\n";
    return 0;
}