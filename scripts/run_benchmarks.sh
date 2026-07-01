#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p build/programs build/golden build/waves results
make -f sim/verilator/verilator.mk benchmark-programs
g++ -std=c++17 -Wall -Wextra -Werror sw/golden/kernel_golden.cpp -o build/golden/kernel_golden

# Read one dot result and four row-major GEMM results.
read -r -a golden_values < <(build/golden/kernel_golden)
bash scripts/build.sh
build/verilator/Vrv32_top --benchmarks "${golden_values[@]}"
