#!/usr/bin/env bash
set -euo pipefail 

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" 
cd "$repo_root" 

mkdir -p build/verilator build/waves results
make -f sim/verilator/verilator.mk build
