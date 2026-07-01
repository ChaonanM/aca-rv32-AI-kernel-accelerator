#include <array>
#include <cstddef>
#include <iostream>
#include <cstdint>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>
#include <iomanip>

#include "verilated.h"
#include "verilated_vcd_c.h"

#include "Vrv32_top.h"

namespace {

constexpr std::uint32_t kMaxCycles = 5000;
constexpr std::size_t   kResultWords = 16;

    struct ExpectedState {
        std::uint32_t x3;
        std::uint32_t x5;
        std::uint32_t x6;
        std::uint32_t dmem0;
        std::uint32_t instruction_count;
        std::uint32_t add_count;
        std::uint32_t mul_count;
        std::uint32_t mac_count;
    };

    struct ProgramCase {
        const char* name;
        const char* data_path;
        ExpectedState expected;
    };

    struct Metrics {
        std::uint32_t cycle_count;
        std::uint32_t instruction_count;
        std::uint32_t add_count;
        std::uint32_t mul_count;
        std::uint32_t mac_count;
        std::array<std::uint32_t, kResultWords> memory;
    };

    struct Observation {
        const char* field;
        std::uint32_t actual;
        std::uint32_t expected;
    };

    struct BenchmarkPair {
        Metrics baseline;
        Metrics custom;
    };

    void tick(Vrv32_top& dut, VerilatedVcdC& trace, vluint64_t& sim_time) {
        dut.clk = 0;
        dut.eval();
        trace.dump(sim_time++);
        dut.clk = 1;
        dut.eval();
        trace.dump(sim_time++);
    }

    std::string create_program_path(const ProgramCase& test) {
        return std::string("build/programs/") + test.name + ".hex";
    }

    std::string create_wave_path(const ProgramCase& test) {
        return std::string("build/waves/") + test.name + ".vcd";
    }

    std::vector<std::uint32_t> load_hex_words(const std::string& path) {
        std::ifstream input(path);
        if (!input) {
            throw std::runtime_error("could not open hex file: " + path);
        } 
        std::vector<std::uint32_t> words;
        std::string line;
        while (std::getline(input, line)) {
            if (line.empty()) {
                continue; 
            }
            std::uint32_t word = 0; 
            std::stringstream parser(line); 
            parser >> std::hex >> word; 
            if (parser.fail()) {
                throw std::runtime_error("invalid hex word in " + path + ": " + line);
            } 
            words.push_back(word); 
        } 
        if (words.empty()) { 
            throw std::runtime_error("hex file is empty: " + path);
        } 
        return words;
    }

    void preload_memories(Vrv32_top& dut, const std::vector<std::uint32_t>& program, const std::vector<std::uint32_t>& data, VerilatedVcdC& trace, vluint64_t& sim_time) {
        for (std::uint32_t index = 0; index < program.size(); ++index) {
            dut.imem_we_i = 1;
            dut.imem_windex_i = index;
            dut.imem_wdata_i = program[index];
            tick(dut, trace, sim_time);
        }
        dut.imem_we_i = 0;
        dut.imem_windex_i = 0;
        dut.imem_wdata_i = 0;
        for (std::uint32_t index = 0; index < data.size(); ++index) {
            dut.dmem_we_i = 1;
            dut.dmem_windex_i = index;
            dut.dmem_wdata_i = data[index];
            tick(dut, trace, sim_time);
        }
        dut.dmem_we_i = 0;
        dut.dmem_windex_i = 0;
        dut.dmem_wdata_i = 0;
        tick(dut, trace, sim_time);
    }

    bool check(const char* test_name, const Observation& observation) {
        if (observation.actual == observation.expected) {
            return true;
        }
        std::cerr << "FAIL: " << test_name << ' ' << observation.field << " expected " << observation.expected << " but got " << observation.actual << '\n'; 
        return false;
    }

    bool run_case(const ProgramCase& test, Metrics* metrics_out = nullptr) {
        
        const std::string program_path = create_program_path(test);
        const std::string wave_path = create_wave_path(test);
        const std::vector<std::uint32_t> program = load_hex_words(program_path);
        const std::vector<std::uint32_t> data = test.data_path == nullptr ? std::vector<std::uint32_t>{} : load_hex_words(test.data_path);
        
        VerilatedContext context;
        context.traceEverOn(true);
        Vrv32_top dut{&context};
        VerilatedVcdC trace;
        dut.trace(&trace, 99);
        trace.open(wave_path.c_str());
        vluint64_t sim_time = 0;

        dut.clk = 0;
        dut.rst_n = 0;
        dut.imem_we_i = 0;
        dut.imem_windex_i = 0;
        dut.imem_wdata_i = 0;
        dut.dmem_we_i = 0;
        dut.dmem_windex_i = 0;
        dut.dmem_wdata_i = 0;
        dut.debug_dmem_index_i = 0;
        dut.eval();
        trace.dump(sim_time++);

        preload_memories(dut, program, data, trace, sim_time);
        dut.rst_n = 1;
        for (std::uint32_t cycle = 0; cycle < kMaxCycles && !dut.done_o; ++cycle) {
            tick(dut, trace, sim_time);
        }
        if (!dut.done_o) {
            std::cerr << "FAIL: " << test.name << " did not halt within" << kMaxCycles << " cycles\n";
            dut.final();
            trace.close();
            return false;
        }
        if (dut.illegal_o) {
            std::cerr << "FAIL: " << test.name << " halted because of an illegal instruction: 0x" << std::hex << dut.debug_illegal_instr << "\n";
            dut.final();
            trace.close();
            return false;
        }

        std::array<std::uint32_t, kResultWords> memory{};
        for (std::size_t index = 0; index < memory.size(); ++index) {
            dut.debug_dmem_index_i = index;
            dut.eval();
            memory[index] = dut.debug_dmem_data_o;
        }
        const Metrics metrics{dut.cycle_count_o, dut.instr_count_o, dut.add_count_o, dut.mul_count_o, dut.mac_count_o, memory};
        tick(dut, trace, sim_time);
        tick(dut, trace, sim_time);
        const Observation observations[] = {
            {"halt", dut.done_o, 1u},
            {"illegal", dut.illegal_o, 0u},
            {"x3", dut.debug_x3_o, test.expected.x3},
            {"x5", dut.debug_x5_o, test.expected.x5},
            {"x6", dut.debug_x6_o, test.expected.x6},
            {"x31", dut.debug_x31_o, 0u},
            {"dmem[0]", metrics.memory[0], test.expected.dmem0},
            {"retired instructions", metrics.instruction_count, test.expected.instruction_count},
            {"retired ADD", metrics.add_count, test.expected.add_count},
            {"retired MUL", metrics.mul_count, test.expected.mul_count},
            {"retired MAC", metrics.mac_count, test.expected.mac_count},
            {"stable cycle count", dut.cycle_count_o, metrics.cycle_count},
            {"stable instruction count", dut.instr_count_o, metrics.instruction_count},
            {"stable ADD count", dut.add_count_o, metrics.add_count},
            {"stable MUL count", dut.mul_count_o, metrics.mul_count},
        };
        bool correct = true; 
        for (const Observation& observation : observations) {
            correct = check(test.name, observation) && correct;
        }
        if (metrics_out != nullptr) {
            *metrics_out = metrics;
        }
        if (correct) {
            std::cout << "PASS: " << test.name << " cycles = " << metrics.cycle_count << ", instructions = " << metrics.instruction_count << ", add_count = " << metrics.add_count << ", mul_count = " << metrics.mul_count << ", mac_count = " << metrics.mac_count << '\n';
        }
        dut.final();
        trace.close();
        return correct;
    }

    bool run_tests() { 
        const ProgramCase tests[] = {
            {"smoke_add", nullptr, {5u, 6u, 5u, 5u, 10u, 1u, 1u, 0u}},
            {"memory_test", nullptr, {0u, 0u, 42u, 42u, 4u, 0u, 0u, 0u}},
            {"branch_loop", nullptr, {6u, 0u, 0u, 15u, 20u, 5u, 0u, 0u}},
            {"mul_test", nullptr, {18u, 54u, 0u, 54u, 7u, 0u, 3u, 0u}},
            {"mac_single", nullptr, {18u, 0u, 0u, 18u, 8u, 0u, 0u, 1u}},
            {"mac_consecutive", nullptr, {23u, 5u, 0u, 23u, 9u, 0u, 0u, 2u}},
            {"mac_x0", nullptr, {0u, 0u, 0u, 0u, 5u, 0u, 0u, 1u}}, 
            {"mac_wrap", nullptr, {0xFFFF'FFF9u, 0u, 0u, 0xFFFF'FFF9u, 6u, 0u, 0u, 1u}},
            {"mac_load_hazards", "sw/data/mac_stress_data.hex", {18u, 13u, 47u, 47u, 16u, 2u, 0u, 3u}}, 
            {"mac_mixed_dependencies",  nullptr, {14u, 83u, 97u, 97u, 10u, 1u, 2u, 2u}}, 
            {"mac_branch_flush", nullptr, {7u, 0u, 0u, 7u, 9u, 0u, 0u, 1u}},
            {"mac_aliasing", nullptr, {1056u, 0u, 0u, 1056u, 7u, 0u, 0u, 3u}},
        }; 
        bool correct = true;
        for (const ProgramCase& test : tests) { 
            correct = run_case(test, nullptr) && correct;
        } 
        return correct;
    }

    void write_metrics(std::ostream& output, const Metrics& metrics) { 
        output << "{\"cycles\":" << metrics.cycle_count << ",\"instructions\":" << metrics.instruction_count << ",\"add_count\":" << metrics.add_count << ",\"mul_count\":" << metrics.mul_count << ",\"mac_count\":" << metrics.mac_count << '}'; 
    }

    double ratio(std::uint32_t numerator, std::uint32_t denominator) {
        return static_cast<double>(numerator) / static_cast<double>(denominator);
    }

    bool check_benchmark_memory(const char* kernel, const char* variant, const Metrics& metrics, const std::vector<std::uint32_t>& expected) {
        bool correct = true;
        for (std::size_t index = 0; index < expected.size(); ++index) {
            if (metrics.memory[index] != expected[index]) {
                std::cerr << "FAIL: " << kernel << ' ' << variant << " dmem[" << index << "] expected " << expected[index] << " but got " << metrics.memory[index] << '\n';
                correct = false;
            }
        }
        return correct;
    }

    bool run_benchmark_pair(const char* kernel, const ProgramCase& baseline_test, const ProgramCase& custom_test, const std::vector<std::uint32_t>& expected, const char* result_path, BenchmarkPair& measured) {
        
        bool correct = run_case(baseline_test, &measured.baseline);
        correct = run_case(custom_test, &measured.custom) && correct;
        correct = check_benchmark_memory(kernel, "baseline", measured.baseline, expected) && correct;
        correct = check_benchmark_memory(kernel, "custom", measured.custom, expected) && correct;
        if (!correct || (measured.baseline.cycle_count == 0u) || (measured.custom.cycle_count == 0u) || (measured.baseline.instruction_count == 0u) || (measured.custom.instruction_count == 0u)) {
            return false;
        }

        const double speedup = ratio(measured.baseline.cycle_count, measured.custom.cycle_count);
        const double instruction_reduction = 1.0 - ratio(measured.custom.instruction_count, measured.baseline.instruction_count);
        
        std::ofstream output(result_path);
        if (!output) {
            std::cerr << "FAIL: cannot write benchmark result " << result_path << '\n'; 
            return false; 
        }
        output << "{\"kernel\":\"" << kernel << "\",\"result\":[";
        for (std::size_t index = 0; index < expected.size(); ++index) {
            output << (index == 0u ? "" : ",") << expected[index];
        }
        output << "],\"baseline\":";
        write_metrics(output, measured.baseline);
        output << ",\"custom\":";
        write_metrics(output, measured.custom);
        output << std::fixed << std::setprecision(6) << ",\"speedup\":" << speedup << ",\"instruction_reduction\":" << instruction_reduction << "}\n";
        std::cout << std::fixed << std::setprecision(3) << "BENCHMARK: " << kernel << ", speedup = " << speedup << ", instruction_reduction = " << instruction_reduction << ", result = " << result_path << '\n';
        return static_cast<bool>(output);
    }

    bool write_blocking_comparison(const BenchmarkPair& scalar, const BenchmarkPair& blocked) {
        
        const double baseline_scalar_blocked_speedup = ratio(scalar.baseline.cycle_count, blocked.baseline.cycle_count);
        const double mac_scalar_blocked_speedup = ratio(scalar.custom.cycle_count, blocked.custom.cycle_count);
        const double combined_speedup = ratio(scalar.baseline.cycle_count, blocked.custom.cycle_count);
        const double baseline_scalar_blocked_instruction_reduction = 1.0 - ratio(blocked.baseline.instruction_count, scalar.baseline.instruction_count);
        const double mac_scalar_blocked_instruction_reduction = 1.0 - ratio(blocked.custom.instruction_count, scalar.custom.instruction_count);
        const double combined_instruction_reduction = 1.0 - ratio(blocked.custom.instruction_count, scalar.baseline.instruction_count);
        
        std::ofstream output("results/gemm_scalar_blocked_comparison.json");
        if (!output) {
            std::cerr << "FAIL: cannot write benchmark result/gemm_scalar_blocked_comparison.json\n"; 
            return false; 
        }
        output << "{\"scalar\":{\"baseline\":";
        write_metrics(output, scalar.baseline);
        output << ",\"mac\":";
        write_metrics(output, scalar.custom);
        output << "},\"blocked_2x2\":{\"baseline\":";
        write_metrics(output, blocked.baseline);
        output << ",\"mac\":";
        write_metrics(output, blocked.custom);
        output << std::fixed << std::setprecision(6) << "},\"baseline_scalar_blocked_speedup\":" << baseline_scalar_blocked_speedup 
                                                     << ",\"mac_scalar_blocked_speedup\":" << mac_scalar_blocked_speedup 
                                                     << ",\"combined_speedup\":" << combined_speedup 
                                                     << ",\"baseline_instruction_reduction\":" << baseline_scalar_blocked_instruction_reduction 
                                                     << ",\"mac_instruction_reduction\":" << mac_scalar_blocked_instruction_reduction 
                                                     << ",\"combined_instruction_reduction\":" << combined_instruction_reduction << "}\n";

        std::cout << std::fixed << std::setprecision(3) << "BENCHMARK: gemm_baseline_scalar_blocked_speedup = " << baseline_scalar_blocked_speedup 
                                                        << ", gemm_mac_scalar_blocked_speedup = " << mac_scalar_blocked_speedup 
                                                        << ", combined_speedup = " << combined_speedup 
                                                        << ", result = results/gemm_scalar_blocked_comparison.json\n"; 
        return static_cast<bool>(output);
    }

    bool run_benchmarks(std::uint32_t dot_golden, const std::vector<std::uint32_t>& gemm_golden) {
        const std::vector<std::uint32_t> dot_expected{dot_golden};
        const ProgramCase dot_baseline{"dot_baseline", "sw/data/dot_baseline_data.hex", {0u, 4u, 8u, dot_golden, 38u, 4u, 4u, 0u}};
        const ProgramCase dot_custom{"dot_mac", "sw/data/dot_baseline_data.hex", {0u, 4u, 8u, dot_golden, 34u, 0u, 0u, 4u}};
        const ProgramCase gemm_baseline{"gemm_baseline", "sw/data/gemm4_data.hex", {64u, 0u, 144u, gemm_golden[0], 681u, 100u, 64u, 0u}};
        const ProgramCase gemm_custom{"gemm_mac", "sw/data/gemm4_data.hex", {64u, 0u, 144u, gemm_golden[0], 617u, 36u, 0u, 64u}};
        const ProgramCase blocked_baseline{"gemm_blocked_baseline", "sw/data/gemm4_data.hex", {64u, 0u, 144u, gemm_golden[0], 375u, 76u, 64u, 0u}};
        const ProgramCase blocked_custom{"gemm_blocked_mac", "sw/data/gemm4_data.hex", {64u, 0u, 144u, gemm_golden[0], 311u, 12u, 0u, 64u}};
        BenchmarkPair dot_metrics{};
        BenchmarkPair gemm_scalar_metrics{};
        BenchmarkPair gemm_blocked_metrics{};
        bool correct = run_benchmark_pair("dot", dot_baseline, dot_custom, dot_expected, "results/dot_comparison.json", dot_metrics);
        correct = run_benchmark_pair("gemm_4x4", gemm_baseline, gemm_custom, gemm_golden, "results/gemm_scalar_comparison.json", gemm_scalar_metrics) && correct;
        correct = run_benchmark_pair("gemm_4x4_blocked_2x2", blocked_baseline, blocked_custom, gemm_golden, "results/gemm_blocked_comparison.json", gemm_blocked_metrics) && correct;
        if (correct) {
            correct = write_blocking_comparison(gemm_scalar_metrics, gemm_blocked_metrics) && correct;
        }
        return correct;
    }
}

int main(int argc, char** argv) {
    try {
        if (argc == 1) {
            return run_tests() ? 0 : 1;
        }
        if ((argc == 19) && (std::string(argv[1]) == "--benchmarks")) {
            const std::uint32_t dot_golden = static_cast<std::uint32_t>(std::stoul(argv[2], nullptr, 0));
            std::vector<std::uint32_t> gemm_golden;
            gemm_golden.reserve(kResultWords);
            for (std::size_t index = 3; index < argc; ++index) {
                gemm_golden.push_back(static_cast<std::uint32_t>(std::stoul(argv[index], nullptr, 0)));
            }
            return run_benchmarks(dot_golden, gemm_golden) ? 0 : 1;
        }
        std::cerr << "usage: " << argv[0] << " [--benchmarks DOT C00 C01 ... C15]\n";
        return 2;
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}