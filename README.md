# Minimal RV32 MAC Core for AI Kernel Acceleration

This repository is a compact hardware/software stack for designing, integrating, and evaluating a custom RISC-V instruction for MAC-intensive AI kernels. It contains a five-stage RV32 pipeline, an independent MAC functional unit, Verilator testbenches, and baseline-versus-MAC dot-product and GEMM benchmarks.

**For now**, the project implements the complete scalar path: a minimal in-order core with hazard handling, a three-source `mac rd, rs1, rs2` instruction, full 4x4 GEMM output checking, and performance metrics.

## What's in the stack

| Layer | Role |
|---|---|
| **RTL** | Five-stage RV32 pipeline, stage-local control, register file, decoder, and arithmetic units (`rtl/`) |
| **Custom ISA** | Scalar MAC semantics and `CUSTOM_0` encoding (`rtl/include/rv32_pkg.sv`, `docs/isa.md`) |
| **Verification** | C++17 Verilator unit tests, complete-core tests, golden checking, and VCD generation |
| **Assembler** | Small Python `.s` to instruction-memory `.hex` assembler (`scripts/assembler.py`) |
| **Software** | Directed assembly programs plus dot-product and GEMM kernels (`sw/asm/`) |
| **Benchmark** | Baseline/MAC comparisons, retirement counters, cycle ratios, and JSON output |
| **Documentation** | ISA_subset (`docs/`) |

## Current focus: scalar MAC and register-blocked GEMM

The current processor extension accelerates 32-bit scalar multiply-accumulate operations:

```text
mac rd, rs1, rs2
x[rd] = (old x[rd] + x[rs1] * x[rs2]) mod 2^32
```

`rd` is both the accumulator input and destination. The MAC unit receives the old register value explicitly and does not keep hidden accumulation state.

The main workload is a 4x4 GEMM with 64 multiply-accumulate operations. The repository contains both a normal scalar-output loop and a 2x2 register-blocked loop that reuses loaded operands across four accumulators.

## Features

### Architecture

- **ISA width:** 32-bit RV32 instructions and 32-bit integer registers
- **Pipeline:** 5 stages (`IF -> ID -> EX -> MEM -> WB`)
- **Issue/retirement:** In-order issue and WB architectural retirement
- **Memory:** Separate 256-word instruction and data memories for simulation
- **Arithmetic:** Single-cycle ALU plus, non-pipelined three-cycle MUL and MAC units
- **Halt:** EBREAK stops fetch, retires in WB, drains the pipeline, then asserts halt
- **Metrics:** Cycle, instruction, ADD, MUL, and MAC counters freeze after final halt

### Instruction Set Support

- **Arithmetic:** ADD, SUB, ADDI
- **Multiplication:** MUL
- **Memory:** LW, SW
- **Branches:** BEQ, BNE, BLT
- **Jump:** JAL
- **Constant:** LUI
- **System:** EBREAK as the simulation halt convention
- **Custom:** MAC using `CUSTOM_0`

This is a small subset, not a complete RV32I or RV32IM implementation.

### Advanced Features

- EX/MEM and MEM/WB register forwarding
- Same-cycle WB-to-ID register-file bypass
- Load-use bubble insertion for `rs1`, `rs2`, and MAC old `rd`
- Taken-branch and JAL pipeline flush
- Multi-cycle EX hold for MUL and MAC
- Third register-file read port for the architectural accumulator
- Wrong-path-safe ADD/MUL/MAC counters at WB retirement
- EBREAK stop-fetch and final pipeline-drain handling
- Independent waveform for the MAC unit, every complete-core case, and every benchmark variant

## Project Structure

```text
.
|-- rtl/
|   |-- include/
|   |   `-- rv32_pkg.sv              # Shared widths, encodings, and operation constants
|   |-- core/
|   |   `-- rv32_core.sv             # Pipeline registers and global control
|   |-- ifu/
|   |   `-- if_stage.sv              # Fetch, hold, redirect, and flush
|   |-- idu/
|   |   |-- decoder.sv               # Baseline and custom instruction decode
|   |   |-- id_stage.sv              # Decode, register reads, and load-use detection
|   |   |-- imm_gen.sv               # Immediate generator
|   |   `-- reg_file.sv              # 32 registers, three read ports, one write port
|   |-- exu/
|   |   |-- alu.sv                   # Integer ALU
|   |   |-- branch_unit.sv           # BEQ, BNE, and signed BLT
|   |   |-- ex_stage.sv              # Forwarding, branch, MUL, and MAC control
|   |   |-- mac_unit.sv              # Three-cycle scalar MAC
|   |   `-- mul_unit.sv              # Three-cycle multiplier
|   |-- mem/
|   |   `-- mem_stage.sv             # Data-memory access and MEM/WB payload
|   |-- wb/
|   |   `-- wb_stage.sv              # Write-back and architectural retirement
|   `-- top/
|       `-- rv32_top.sv              # Core && simulation IMEM/DMEM
|-- sim/verilator/
|   |-- tb_core.cpp                  # Shared complete-core and benchmark
|   `-- verilator.mk                 # RTL lists, assembly targets, and build rules
|-- tests/unit/                      # Focused C++ leaf-module tests
|-- sw/
|   |-- asm/                         # Directed tests and benchmark assembly
|   |-- data/                        # Dot, GEMM, and hazard-test data images
|   `-- golden/kernel_golden.cpp     # Independent dot/GEMM golden model
|-- scripts/
|   |-- assembler.py                 # Minimal custom assembler
|   |-- build.sh                     # Complete-core Verilator build
|   |-- run_tests.sh                 # Unit and directed core regression
|   `-- run_benchmarks.sh            # Golden model and benchmark comparison
|-- arch/                            # Architecture
|-- docs/                            # ISA, RISC-V reference
`-- results/                         # Generated benchmark JSON files
```

## Prerequisites

| Tool | Purpose |
|---|---|
| **Verilator** | Compile and run SystemVerilog RTL with the C++ testbenches |
| **g++ / build-essential** | Build Verilator models and the independent golden model |
| **Python 3** | Run the custom assembler |
| **GNU Make** | Apply the central Verilator source list and generated-program rules |
| **GTKWave (optional)** | Inspect generated VCD waveforms |

No RISC-V GNU compiler, assembler, ELF linker, or C runtime is required.

## Quick Start

### 1. Run the directed regression

From the repository root:

```bash
bash scripts/run_tests.sh
```

This command checks the custom MAC encoding, assembles all directed programs, builds and runs the leaf-unit tests, builds the complete core, executes every core case, and writes one waveform per case.

### 2. Run the benchmark suite

```bash
bash scripts/run_benchmarks.sh
```

The benchmark flow assembles six kernel programs, builds the host golden model, checks dot product and all 16 GEMM outputs, verifies retirement counts, and writes comparison JSON only after correctness passes.

### 3. Inspect results

```bash
python3 -m json.tool results/dot_comparison.json
python3 -m json.tool results/gemm_scalar_comparison.json
python3 -m json.tool results/gemm_blocked_comparison.json
python3 -m json.tool results/gemm_scalar_blocked_comparison.json
```

Open an individual waveform with:

```bash
gtkwave build/waves/gemm_blocked_mac.vcd
```

### 4. Assemble one program

```bash
python3 scripts/assembler.py sw/asm/gemm_blocked_mac.s \
  -o build/programs/gemm_blocked_mac.hex
```

## Custom Assembler

`scripts/assembler.py` is the only `.s` to `.hex` path used by this core. It is a small assembler for the implemented subset and custom MAC instruction.

```bash
python3 scripts/assembler.py <input.s> -o <output.hex>
```

The output contains one hexadecimal 32-bit instruction word per line and can be preloaded directly into `rv32_top` instruction memory.

## Custom MAC Instruction

### Encoding

The extension uses an R-type-like layout in the standard RISC-V `CUSTOM_0` major opcode space.

| Bits | Field | Value or role |
|---|---|---|
| `31:25` | `funct7` | `0000001` |
| `24:20` | `rs2` | operand B |
| `19:15` | `rs1` | operand A |
| `14:12` | `funct3` | `000` |
| `11:7` | `rd` | Old accumulator and destination |
| `6:0` | `opcode` | `0001011` (`CUSTOM_0`) |

```text
mac x3, x1, x2 = 0x0220818b
```

### Three-source dependency

`mac x3, x1, x2` reads x1, x2, and old x3, then writes x3. Decoder metadata, the third register-file read port, load-use detection, and forwarding all treat old `rd` as a third source. This is required for correct consecutive MAC, load-to-accumulator, and register-alias behavior.

## Arithmetic Units

### ALU and branch (`rtl/exu/alu.sv`, `rtl/exu/branch_unit.sv`)

The ALU handles integer arithmetic, address generation, and LUI pass-through within 1 clock cycle. Branch comparison is kept in a separate combinational unit and redirects the fetch PC from EX.

### Multiply (`rtl/exu/mul_unit.sv`)

The `mul_unit` inserts an extra 3-cycle latency compared with `ALU`. A MUL remains in EX and stalls younger instructions until the result is available. The result is the low 32 bits of the product.

### Multiply-accumulate (`rtl/exu/mac_unit.sv`)

The independent `mac_unit` uses the same extra 3-cycle latency:

```text
product = (lhs * rhs) mod 2^32
result  = (accumulator + product) mod 2^32
```

The unit stores only the accepted operation result and a remaining-cycle counter. It has no hidden accumulator. Consecutive MAC instructions receive the latest partial sum through normal EX/MEM or MEM/WB forwarding.

Because MUL and MAC have the same configured latency, the comparison does not assume an artificially shorter MAC. The custom instruction removes the dependent accumulation ADD and associated instruction-flow overhead. 

The blocked GEMM provides a separate optimization of 2×2 register-blocked 4×4 GEMM through operand reuse and fewer loads.

## Verification

Baseline leaf and complete-core checks establish that decode, arithmetic, memory, control flow, forwarding, retirement, and EBREAK drain work before accelerator results are accepted.

### MAC unit and pipeline integration

The `tb_mac_unit.cpp` verifies arithmetic wraparound, extra 3-cycle latency, one-request-at-a-time behavior and consecutive requests. 

Complete-core MAC cases verify the architectural integration rather than only the arithmetic result:

- all three immediate load dependencies: `LW -> rs1`, `LW -> rs2`, and `LW -> old rd`
- consecutive accumulator forwarding through EX/MEM and MEM/WB
- mixed MUL/MAC/ADD dependency chains
- wrong-path MAC removal after a taken branch
- `rd` aliasing with either or both multiplicand registers
- `rd=x0`, WB retirement counts, and final pipeline drain

### Benchmark correctness and fairness

`sw/golden/kernel_golden.cpp` independently computes dot result 70 and all 16 row-major GEMM outputs. Baseline and MAC variants use the same input images and perform the same mathematical work. 

The testbench checks every output word and expected instruction/ADD/MUL/MAC retirement counts before it writes cycles or speedup, so an incorrect run cannot publish performance data.

## Memory Map

### Simulation memories

| Memory | Depth | Width | Byte-address range | Notes |
|---|---:|---:|---:|---|
| Instruction memory | 256 words | 32-bit | `0x000-0x3ff` | Reset PC is `0x00000000`; testbench preload |
| Data memory | 256 words | 32-bit | `0x000-0x3ff` | Testbench preload |

The architecture uses a small Harvard-style simulation memory system. Reads are combinational and writes occur on the rising edge. Programs use aligned word accesses within the implemented address range.

### GEMM data layout

| Data-memory range | Word indices | Contents |
|---|---:|---|
| `0x000-0x03f` | 0-15 | 4x4 output matrix C |
| `0x040-0x07f` | 16-31 | 4x4 input matrix A |
| `0x080-0x0bf` | 32-47 | 4x4 input matrix B |

## Performance

### ISA-level instruction results

The benchmark calculates:

```text
speedup = baseline_cycles / custom_cycles
dynamic instructions reduction = 1 - (custom_instructions / baseline_instructions)
```

The custom assembler and ISA-level execution verify these code sizes and dynamic retirement totals:

| Benchmark | Baseline static words | MAC static words | Baseline instructions | MAC instructions | Dynamic reduction | Baseline cycles | MAC cycles | SpeedUp |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Dot product | 14 | 13 | 38 | 34 | 10.5263% | 64 | 60 | 1.066667 |
| Scalar 4x4 GEMM | 27 | 26 | 681 | 617 | 9.3979% | 1067 | 1003 | 1.063809 |
| 2x2 blocked 4x4 GEMM | 47 | 43 | 375 | 311 | 17.0667% | 601 | 537 | 1.119181 | 

The blocked GEMM reduces loads from 128 to 64. 

Relative to scalar GEMM, it reduces dynamic instructions by 44.9339% for baseline code and 49.5948% for MAC code.

Compared with scalar GEMM, its speedup ratio is 1.775374 for baseline code and 1.867784 for MAC code.

### Output files

| Comparison | Generated artifact |
|---|---|
| Dot baseline vs MAC | `results/dot_comparison.json` |
| Scalar GEMM baseline vs MAC | `results/gemm_scalar_comparison.json` |
| Blocked GEMM baseline vs MAC | `results/gemm_blocked_comparison.json` |
| Scalar vs blocked cross-comparison | `results/gemm_scalar_blocked_comparison.json` |
