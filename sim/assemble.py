#!/usr/bin/env python3
"""
Minimal RV32I assembler for the Phase-1 instruction subset:
ADD, SUB, ADDI, AND, OR, XOR, LW, SW, BEQ, JAL, JALR, LUI.

Not a general-purpose assembler — just enough to hand-generate the
test program reliably instead of encoding instructions by hand.
Branch/jump immediates are given as byte offsets (pc-relative), matching
RISC-V assembly convention.
"""
import sys

def reg(r):
    return int(r[1:])

def sext(val, bits):
    val &= (1 << bits) - 1
    return val

def r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (reg(rs2) << 20) | (reg(rs1) << 15) | (funct3 << 12) | (reg(rd) << 7) | opcode

def i_type(imm, rs1, funct3, rd, opcode):
    imm = sext(imm, 12)
    return (imm << 20) | (reg(rs1) << 15) | (funct3 << 12) | (reg(rd) << 7) | opcode

def s_type(imm, rs2, rs1, funct3, opcode):
    imm = sext(imm, 12)
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0 = imm & 0x1F
    return (imm11_5 << 25) | (reg(rs2) << 20) | (reg(rs1) << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def b_type(imm, rs2, rs1, funct3, opcode):
    imm = sext(imm, 13)
    bit12 = (imm >> 12) & 0x1
    bit11 = (imm >> 11) & 0x1
    bits10_5 = (imm >> 5) & 0x3F
    bits4_1 = (imm >> 1) & 0xF
    return (bit12 << 31) | (bits10_5 << 25) | (reg(rs2) << 20) | (reg(rs1) << 15) | \
           (funct3 << 12) | (bits4_1 << 8) | (bit11 << 7) | opcode

def u_type(imm, rd, opcode):
    return ((imm & 0xFFFFF) << 12) | (reg(rd) << 7) | opcode

def j_type(imm, rd, opcode):
    imm = sext(imm, 21)
    bit20 = (imm >> 20) & 0x1
    bits10_1 = (imm >> 1) & 0x3FF
    bit11 = (imm >> 11) & 0x1
    bits19_12 = (imm >> 12) & 0xFF
    return (bit20 << 31) | (bits19_12 << 12) | (bit11 << 20) | (bits10_1 << 21) | (reg(rd) << 7) | opcode

OP_R, OP_I, OP_LOAD, OP_STORE, OP_BRANCH, OP_JAL, OP_JALR, OP_LUI = \
    0b0110011, 0b0010011, 0b0000011, 0b0100011, 0b1100011, 0b1101111, 0b1100111, 0b0110111

def ADD(rd, rs1, rs2):  return r_type(0b0000000, rs2, rs1, 0b000, rd, OP_R)
def SUB(rd, rs1, rs2):  return r_type(0b0100000, rs2, rs1, 0b000, rd, OP_R)
def AND(rd, rs1, rs2):  return r_type(0b0000000, rs2, rs1, 0b111, rd, OP_R)
def OR(rd, rs1, rs2):   return r_type(0b0000000, rs2, rs1, 0b110, rd, OP_R)
def XOR(rd, rs1, rs2):  return r_type(0b0000000, rs2, rs1, 0b100, rd, OP_R)
def ADDI(rd, rs1, imm): return i_type(imm, rs1, 0b000, rd, OP_I)
def LW(rd, imm, rs1):   return i_type(imm, rs1, 0b010, rd, OP_LOAD)
def SW(rs2, imm, rs1):  return s_type(imm, rs2, rs1, 0b010, OP_STORE)
def BEQ(rs1, rs2, imm): return b_type(imm, rs2, rs1, 0b000, OP_BRANCH)
def JAL(rd, imm):       return j_type(imm, rd, OP_JAL)
def JALR(rd, rs1, imm): return i_type(imm, rs1, 0b000, rd, OP_JALR)
def LUI(rd, imm):       return u_type(imm, rd, OP_LUI)

# ---- Phase 1 test program -------------------------------------------
# idx : instruction                              byte addr
prog = [
    ADDI('x1', 'x0', 5),            # 0  x1 = 5
    ADDI('x2', 'x0', 10),           # 1  x2 = 10
    ADD ('x3', 'x1', 'x2'),         # 2  x3 = 15
    SUB ('x4', 'x2', 'x1'),         # 3  x4 = 5
    AND ('x5', 'x1', 'x2'),         # 4  x5 = 0
    OR  ('x6', 'x1', 'x2'),         # 5  x6 = 15
    XOR ('x7', 'x1', 'x2'),         # 6  x7 = 15
    SW  ('x3', 0, 'x0'),            # 7  mem[0] = 15
    LW  ('x8', 0, 'x0'),            # 8  x8 = 15
    LUI ('x9', 0x12345),            # 9  x9 = 0x12345000
    BEQ ('x1', 'x1', 8),            # 10 taken: pc(40)+8=48 -> idx12
    ADDI('x10', 'x0', 999),         # 11 SKIPPED
    ADDI('x10', 'x0', 111),         # 12 x10 = 111
    BEQ ('x1', 'x2', 8),            # 13 not taken (5 != 10)
    ADDI('x11', 'x0', 222),         # 14 x11 = 222
    JAL ('x12', 12),                # 15 pc(60), link x12=64, target=72 -> idx18
    ADDI('x16', 'x0', 999),         # 16 SKIPPED
    ADDI('x16', 'x0', 888),         # 17 SKIPPED
    ADDI('x17', 'x0', 77),          # 18 x17 = 77  (JAL landed here)
    ADDI('x18', 'x0', 84),          # 19 x18 = 84  (byte addr of idx21)
    JALR('x19', 'x18', 0),          # 20 pc(80), link x19=84, target=84 -> idx21
    ADDI('x20', 'x0', 55),          # 21 x20 = 55  (JALR landed here)
    JAL ('x0', 0),                  # 22 halt: self-loop (link discarded, rd=x0)
]

with open(sys.argv[1] if len(sys.argv) > 1 else 'programs/test_program.hex', 'w') as f:
    for i, word in enumerate(prog):
        f.write(f"{word & 0xFFFFFFFF:08x}\n")

print(f"Assembled {len(prog)} instructions.")
