TOP_MODULE := rv32_top

BUILD_DIR := build/verilator
SIM_BINARY := $(BUILD_DIR)/V$(TOP_MODULE)

RTL_SOURCES := rtl/include/rv32_pkg.sv \
  rtl/ifu/if_stage.sv \
  rtl/idu/reg_file.sv \
  rtl/idu/imm_gen.sv \
  rtl/idu/decoder.sv \
  rtl/idu/id_stage.sv \
  rtl/exu/branch_unit.sv \
  rtl/exu/mul_unit.sv \
  rtl/exu/mac_unit.sv \
  rtl/exu/alu.sv \
  rtl/exu/ex_stage.sv \
  rtl/mem/mem_stage.sv \
  rtl/wb/wb_stage.sv \
  rtl/core/rv32_core.sv \
  rtl/top/rv32_top.sv 

TB_SOURCES := sim/verilator/tb_core.cpp

PROGRAM_NAMES := smoke_add \
  memory_test \
  branch_loop \
  mul_test \
  mac_single \
  mac_consecutive \
  mac_x0 \
  mac_wrap \
  mac_load_hazards \
  mac_mixed_dependencies \
  mac_branch_flush \
  mac_aliasing

PROGRAM_HEX := $(addprefix build/programs/,$(addsuffix .hex,$(PROGRAM_NAMES)))

BENCHMARK_NAMES := dot_baseline \
  dot_mac \
  gemm_baseline \
  gemm_mac \
  gemm_blocked_baseline \
  gemm_blocked_mac 

BENCHMARK_HEX := $(addprefix build/programs/,$(addsuffix .hex, $(BENCHMARK_NAMES)))

VERILATOR_FLAGS := --cc --exe --build --trace --trace-structs --top-module $(TOP_MODULE) --Mdir $(BUILD_DIR) #-Wall 

# Mark command targets as phony so make does not confuse them with files.
.PHONY: build programs benchmark-programs run clean

build/programs/%.hex: sw/asm/%.s scripts/assembler.py 
	mkdir -p build/programs 
	python3 scripts/assembler.py $< -o $@ 

programs: $(PROGRAM_HEX) 

benchmark-programs: $(BENCHMARK_HEX)

build: 
	verilator $(VERILATOR_FLAGS) $(RTL_SOURCES) $(TB_SOURCES) 

run: programs build 
	$(SIM_BINARY) 

clean: 
	rm -rf build results
  