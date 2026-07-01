#include <cstdint>
#include <iostream>

#include "Vreg_file.h"

namespace {

    void tick(Vreg_file& dut) {
        dut.clk = 0;
        dut.eval();
        dut.clk = 1;
        dut.eval();
    }

    bool expect_equal(const char* name, std::uint32_t actual, std::uint32_t expected) {
        if (actual != expected) {
            std::cerr << "REGFILE FAIL: " << name << " expected " << expected << " but got " << actual << '\n';
            return false;
        }
        return true;
    }
}

int main() {
    Vreg_file dut;
    dut.clk = 0;
    dut.rst_n = 0;
    dut.raddr0_i = 0;
    dut.raddr1_i = 0;
    dut.raddr2_i = 0;
    dut.we_i = 0;
    dut.waddr_i = 0;
    dut.wdata_i = 0;
    tick(dut);

    dut.rst_n = 1;
    dut.we_i = 1;
    dut.waddr_i = 7;
    dut.wdata_i = 0xCAFE'BABEu;
    tick(dut);
    dut.waddr_i = 3;
    dut.wdata_i = 0x0000'0123u;
    tick(dut);
    dut.waddr_i = 0;
    dut.wdata_i = 0xFFFF'FFFFu;
    tick(dut);

    dut.we_i = 0;
    dut.raddr0_i = 7;
    dut.raddr1_i = 3;
    dut.raddr2_i = 0;
    dut.eval();

    bool correct = true;
    correct = expect_equal("x7 on read port 0", dut.rdata0_o, 0xCAFE'BABEu) && correct;
    correct = expect_equal("x3 on read port 1", dut.rdata1_o, 0x0000'0123u) && correct;
    correct = expect_equal("x0 on read port 2", dut.rdata2_o, 0u) && correct;
    correct = expect_equal("debug x3", dut.debug_x3_o, 0x0000'0123u) && correct;

    dut.we_i = 1;
    dut.waddr_i = 3;
    dut.wdata_i = 0x1357'9BDFu;
    dut.raddr0_i = 3;
    dut.raddr1_i = 3;
    dut.raddr2_i = 3;
    dut.clk = 0;
    dut.eval();
    correct = expect_equal("WB bypass on read port 0", dut.rdata0_o, 0x1357'9BDFu) && correct;
    correct = expect_equal("WB bypass on read port 1", dut.rdata1_o, 0x1357'9BDFu) && correct; 
    correct = expect_equal("WB bypass on read port 2", dut.rdata2_o, 0x1357'9BDFu) && correct;
    correct = expect_equal("old value in x3", dut.debug_x3_o, 0x0000'0123u) && correct;
    tick(dut);
    correct = expect_equal("new value in x3", dut.debug_x3_o, 0x1357'9BDFu) && correct;
    dut.final();
    if (!correct)
        return 1;
    std::cout << "UNIT PASS: regfile normal writes, three reads, debug output, and x0 protection\n";
    return 0;
}