# RV32 ISA Contract and Scalar MAC Extension

## 1. Scope

This project implements a minimal RV32 subset plus one scalar custom MAC instruction. The ISA is sufficient for directed processor tests, dot product, and looped 4x4 GEMM. 


The shared RTL constants are defined in `rtl/include/rv32_pkg.sv`. Assembly source is encoded directly to instruction-memory hex by `scripts/assemble.py`.

## 2. Architectural State

| State | Contract |
|---|---|
| Integer registers | 32 registers `x0..x31`, each 32-bit |
| Zero register | `x0` always reads zero; writes are discarded |
| Program counter | 32-bit byte address, reset value `0x00000000` |
| Memory access | Aligned 32-bit `LW` and `SW` in the current programs |
| Arithmetic overflow  | Modulo-2^32 wraparound |

## 3. Supported Instructions

| Category | Instruction | Format | Purpose |
|---|---|---|---|
| Arithmetic | `add rd, rs1, rs2` | R | Register addition |
| Arithmetic | `sub rd, rs1, rs2` | R | Register subtraction  |
| Arithmetic | `addi rd, rs1, imm` | I | Immediate addition, pointers, counters |
| Multiply| `mul rd, rs1, rs2` | R | Low 32-bit baseline product |
| Memory | `lw rd, imm(rs1)` | I | Load one 32-bit word |
| Memory | `sw rs2, imm(rs1)` | S | Store one 32-bit word |
| Branch | `beq rs1, rs2, target` | B | Branch if equal |
| Branch | `bne rs1, rs2, target` | B | Branch if not equal |
| Branch | `blt rs1, rs2, target` | B | Signed less-than branch |
| Jump | `jal rd, target` | J | PC-relative jump and link |
| Constant | `lui rd, imm20` | U | Load upper immediate |
| Simulation | `ebreak` | I/System | Stop fetch, retire, drain, halt |
| Custom | `mac rd, rs1, rs2` | R-like | Scalar multiply-accumulate |

EBREAK is a simulation halt instruction. Decode stops younger fetches, but EBREAK and all older instructions continue through the pipeline. The core asserts final halt only after EBREAK retires in WB and the pipeline is empty. EBREAK is included in the retired instruction count.

This convention does not implement the standard privileged/debug behavior of EBREAK.

## 4. Instruction Formats 

| Format | Bit layout | Used by |
|---|---|---|
| R | `funct7 rs2 rs1 funct3 rd opcode` | `add`, `sub`, `mul`, `mac` |
| I | `imm[11:0] rs1 funct3 rd opcode` | `addi`, `lw`, `ebreak` |
| S | `imm[11:5] rs2 rs1 funct3 imm[4:0] opcode` | `sw` |
| B | `imm[12\|10:5] rs2 rs1 funct3 imm[4:1\|11] opcode` | `beq`, `bne`, `blt` |
| U | `imm[31:12] rd opcode` | `lui` |
| J | `imm[20\|10:1\|11\|19:12] rd opcode` | `jal` |

Branch and jump immediates are PC-relative byte offsets. Their encoded fields are non-contiguous, so the `assembler.py` splits label offsets and `imm_gen.sv` reconstructs them.

### Baseline Encoding Summary

| Instruction | Opcode | `funct3` | `funct7` or immediate / `funct7` |
|---|---:|---:|---:|
| `add` | `0110011` | `000` | `0000000` |
| `sub` | `0110011` | `000` | `0100000` |
| `mul` | `0110011` | `000` | `0000001` |
| `addi` | `0010011` | `000` | `imm12` |
| `lw` | `0000011` | `010` | `imm12` |
| `sw` | `0100011` | `010` | store immediate |
| `beq` | `1100011` | `000` | branch immediate |
| `bne` | `1100011` | `001` | branch immediate |
| `blt` | `1100011` | `100` | branch immediate |
| `jal` | `1101111` | - | jump immediate |
| `lui` | `0110111` | - | upper immediate |
| `ebreak` | `1110011` | `000` | instruction word `0x00100073` |

## 5. Scalar MAC

### Semantics

```text
mac rd, rs1, rs2

product = (x[rs1] * x[rs2]) mod 2^32
x[rd]   = (old x[rd] + product) mod 2^32
```

| Role | Field |
|---|---|
| Multiplicand A | `rs1` |
| Multiplicand B | `rs2` |
| Accumulator input | old `rd` |
| Destination | `rd` |

The result wraps to 32 bits and is not saturated. Signed and unsigned 32x32 multiplication produce the same low 32 product bits. When `rd=x0`, the operation may execute but the architectural write is discarded.

### Encoding 

The instruction uses an R-type-like layout in the standard RISC-V `CUSTOM_0` major opcode space.


| Bits | Field | Value or role |
|---|---|---|
| `31:25` | `funct7` | `0000001` |
| `24:20` | `rs2` | Multiplicand B |
| `19:15` | `rs1` | Multiplicand A |
| `14:12` | `funct3` | `000` |
| `11:7` | `rd` | Old accumulator and destination |
| `6:0` | `opcode` | `0001011` (`CUSTOM_0`) |

```text
instruction = funct7<<25 | rs2<<20 | rs1<<15 | funct3<<12 | rd<<7 | opcode
example: mac x3, x1, x2 = 0x0220818b
```

The stable RTL constants in `rtl/include/rv32_pkg.sv` are:

```systemverilog
OPCODE_CUSTOM_0 = 7'b0001011
FUNCT3_MAC      = 3'b000
FUNCT7_MAC      = 7'b0000001
```

## 6. Three-Source Pipeline Contract

MAC reads `rs1`, `rs2`, and old `rd`, then writes `rd`. So correct integration requires all three sources to participate in operand collection, load-use detection, and forwarding.

- Decoder produces `OP_MAC` and `uses_rd_old`.
- Register file port-3 reads old `rd`.
- ID/EX carries old `rd` and its source-use metadata.
- Load-use interlock checks `rs1`, `rs2`, and old `rd`.
- EX/MEM and MEM/WB forwarding covers all three operands.
- `mac_unit.sv` receives and stores the accumulator explicitly without hidden accumulator in `mac_unit.sv`.
- `mac_unit.sv` is not pipelined.
- MAC is counted only when it retires in WB.

## 7. Assembler Interface

```bash
python3 scripts/assemble.py input.s -o build/programs/input.hex
```

The assembler accepts the instructions in this document, `x0..x31`, the `zero` alias, numeric immediates, and labels. It writes one hexadecimal 32-bit word per line. It does not use a GNU RISC-V assembler, ELF, linker, ABI, or startup runtime.

