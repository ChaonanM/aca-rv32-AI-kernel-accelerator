#!/usr/bin/env python3
"""
Minimal assembler for the RV32 subset.
""" 

import argparse  
from pathlib import Path

XLEN_MASK = 0xFFFFFFFF  
WORD_BYTES = 4  

R_TYPE = {  
    "add": (0b0110011, 0b000, 0b0000000),  
    "sub": (0b0110011, 0b000, 0b0100000), 
    "mul": (0b0110011, 0b000, 0b0000001), 
    "mac": (0b0001011, 0b000, 0b0000001),
}  

I_TYPE = { 
    "addi": (0b0010011, 0b000),  
    "lw": (0b0000011, 0b010), 
} 

S_TYPE = { 
    "sw": (0b0100011, 0b010),
}

B_TYPE = {
    "beq": (0b1100011, 0b000), 
    "bne": (0b1100011, 0b001), 
    "blt": (0b1100011, 0b100), 
} 

U_TYPE = {
    "lui": 0b0110111,
}

U_J_TYPE = {
    "jal": 0b1101111, 
}

def operands(text: str) -> list[str]:
    text = text.replace("(", ",").replace(")", "")
    return [part.strip() for part in text.split(",") if part.strip()]

def reg(name: str) -> int:
    name = name.strip().lower()
    if name == "zero":
        return 0
    if name.startswith("x") and name[1:].isdigit():
        value = int(name[1:])
        if 0 <= value <= 31:
            return value
    raise ValueError(f"unknown register '{name}', expected x0...x31 or zero")

def imm(immediate: str) -> int:
    try:
        return int(immediate.strip(), 0)
    except ValueError as exc:
        raise ValueError(f"invalid immediate '{immediate}'") from exc

def signed(value: int, bits: int, name: str) -> int:
    if value < -(1 << (bits - 1)) or value >= (1 << (bits - 1)):
        raise ValueError(f"{name} {value} does not fit in signed {bits} bits")
    return value & ((1 << bits) - 1)

def unsigned(value: int, bits: int, name: str) -> int:
    if value < 0 or value >= (1 << bits):
        raise ValueError(f"{name} {value} does not fit in unsigned {bits} bits")
    return value

def target(label: str, labels: dict[str, int], pc: int) -> int:
    return labels[label] - pc if label in labels else imm(label)

def encode_r_type(opcode: int, funct3: int, funct7: int, args: list[str]) -> int:
    if len(args) != 3:
        raise ValueError("R-type expects rd, rs1, rs2")
    rd, rs1, rs2 = reg(args[0]), reg(args[1]), reg(args[2])
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_i_type(opcode: int, funct3: int, op: str, args: list[str]) -> int:
    if op == "addi" and len(args) == 3:
        rd, rs1, offset = reg(args[0]), reg(args[1]), imm(args[2])
    elif op == "lw" and len(args) == 3:
        rd, rs1, offset = reg(args[0]), reg(args[2]), imm(args[1])
    else:
        raise ValueError(f"{op} has malformed operands")
    return (signed(offset, 12, "I-immediate") << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_s_type(opcode: int, funct3: int, args: list[str]) -> int:
    if len(args) != 3:
        raise ValueError("sw expects rs2, imm(rs1)")
    rs2, offset, rs1 = reg(args[0]), imm(args[1]), reg(args[2])
    field = signed(offset, 12, "S-immediate")
    return ((field >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((field & 0x1F) << 7) | opcode

def encode_b_type(opcode: int, funct3: int, args: list[str], labels: dict[str, int], pc: int) -> int:
    if len(args) != 3:
        raise ValueError(f"branch expects rs1, rs2, target")
    rs1, rs2 = reg(args[0]), reg(args[1])
    offset = target(args[2], labels, pc)
    if offset % 2:
        raise ValueError(f"branch offset {offset} is not 2-byte aligned")
    field = signed(offset, 13, "branch offset")
    return (((field >> 12) & 1) << 31) | (((field >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (((field >> 1) & 0xF) << 8) | (((field >> 11) & 1) << 7) | opcode

def encode_u_type(opcode: int, args: list[str]) -> int:
    if len(args) != 2:
        raise ValueError("lui expects rd, imm20")
    rd, u_imm = reg(args[0]), unsigned(imm(args[1]), 20, "U-immediate")
    return (u_imm << 12) | (rd << 7) | opcode

def encode_uj_type(opcode: int, args: list[str], labels: dict[str, int], pc: int) -> int:
    if len(args) != 2:
        raise ValueError("jal expects rd, target")
    offset = target(args[1], labels, pc)
    if offset % 2:
        raise ValueError(f"jump offset {offset} is not 2-byte aligned")
    field = signed(offset, 21, "jump offset")
    return (((field >> 20) & 1) << 31) | (((field >> 1) & 0x3FF) << 21) | (((field >> 11) & 1) << 20) | (((field >> 12) & 0xFF) << 12) | (reg(args[0]) << 7) | opcode

def encode(pc: int, labels: dict[str, int], instruction: str) -> int:
    op, _, rest = instruction.partition(" ")
    op = op.lower()
    args = operands(rest)
    if op in R_TYPE:
        return encode_r_type(*R_TYPE[op], args)
    if op in I_TYPE:
        return encode_i_type(*I_TYPE[op], op, args)
    if op in S_TYPE:
        return encode_s_type(*S_TYPE[op], args)
    if op in B_TYPE:
        return encode_b_type(*B_TYPE[op], args, labels, pc)
    if op in U_TYPE:
        return encode_u_type(*U_TYPE[op], args)
    if op in U_J_TYPE:
        return encode_uj_type(*U_J_TYPE[op], args, labels, pc)
    if op == "ebreak" and not args:
        return 0x00100073
    raise ValueError(f"unsupported or malformed instruction '{instruction}'")

def collect_labels(lines: list[str]) -> tuple[dict[str, int], list[tuple[int, int, str]]]:
    labels: dict[str, int] = {}
    instructions: list[tuple[int, str, str]] = []
    pc = 0
    for line_no, line in enumerate(lines):
        while ":" in line:
            label, line = line.split(":", 1)
            label = label.strip()
            if not label or not (label[0].isalpha() or label[0] == "_") or not all(ch.isalnum() or ch == "_" for ch in label):
                raise ValueError(f"line {line_no}: invalid label '{label}'")
            if label in labels:
                raise ValueError(f"line {line_no}: duplicate label '{label}'")
            labels[label] = pc
            line = line.strip()
            if not line:
                break
        if line:
            instructions.append((line_no, pc, line))
            pc += WORD_BYTES
    return labels, instructions


def assemble(input_path: Path) -> list[int]:
    lines = input_path.read_text(encoding="utf-8").splitlines()
    labels, instructions = collect_labels(lines)
    instr_hex: list[int] = []
    for line_no, pc, instrction in instructions:
        try:
            instr_hex.append(encode(pc, labels, instrction) & XLEN_MASK)
        except ValueError as exc:
            raise ValueError(f"line {line_no}: {exc}")
    return instr_hex    

def main() -> int:
    parser = argparse.ArgumentParser(description="Assemble the RV32 subset into hex words.")
    parser.add_argument("input", type=Path, help="assembly source file, sw/asm/*.s")
    parser.add_argument("-o", "--output", type=Path, required=True, help="output hex file under build/programs/")
    args = parser.parse_args()
    try:
        instr_hex = assemble(args.input)
    except ValueError as exc:
        parser.error(str(exc))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("".join(f"{inst:08x}\n" for inst in instr_hex), encoding="utf-8")
    print(f"assembled {len(instr_hex)} instructions, file path: {args.output}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())