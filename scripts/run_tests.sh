#!/usr/bin/env bash

set -euo pipefail 

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" 
cd "$repo_root"

mkdir -p build/programs build/unit build/waves

# Check that the assembler runtime is available.
if ! command -v python3 >/dev/null 2>&1; then 
    echo "error: python3 is not installed or not on PATH" >&2
    exit 127
fi

# Check that the RTL unit-test and integration-test compiler is available.
if ! command -v verilator >/dev/null 2>&1; then
    echo "error: verilator is not installed or not on PATH" >&2 
    echo "install in WSL with: sudo apt-get update && sudo apt-get install -y verilator build-essential" >&2 
    exit 127
fi

make -f sim/verilator/verilator.mk programs

build_and_run_unit() {
    local top_module="$1"
    local rtl_source="$2"
    local tb_source="$3"
    local unit_dir="build/unit/${top_module}"
    verilator --cc --exe --build --trace --trace-structs --top-module "$top_module" --Mdir "$unit_dir" rtl/include/rv32_pkg.sv "$rtl_source" "$tb_source"
    "${unit_dir}/V${top_module}"
}

build_and_run_unit reg_file rtl/idu/reg_file.sv tests/unit/tb_reg_file.cpp
build_and_run_unit imm_gen rtl/idu/imm_gen.sv tests/unit/tb_imm_gen.cpp
build_and_run_unit decoder rtl/idu/decoder.sv tests/unit/tb_decoder.cpp
build_and_run_unit alu rtl/exu/alu.sv tests/unit/tb_alu.cpp
build_and_run_unit branch_unit rtl/exu/branch_unit.sv tests/unit/tb_branch_unit.cpp
build_and_run_unit mac_unit rtl/exu/mac_unit.sv tests/unit/tb_mac_unit.cpp

bash scripts/build.sh 
build/verilator/Vrv32_top 