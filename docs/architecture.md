# Phase 1 Architecture Notes

## Datapath

```
        +----------+        +-------------------+
        |   PC     |------->| instruction_memory |---> instr
        +----------+        +-------------------+
             ^                        |
             | pc_next                v
             |                 [opcode/rd/funct3/rs1/rs2/funct7]
             |                        |
             |                 +-------------+       +-----------------+
             |                 | control_unit|------->| immediate_gen   |
             |                 +-------------+        +-----------------+
             |                        |                        |
             |                        v                        v
             |                 reg_write, mem_read,       imm_out
             |                 mem_write, alu_src_a/b,
             |                 alu_control, branch,
             |                 jump, jalr, result_src
             |                        |
             |                 +-------------+
             |                 | register_file|<---- rd_data (writeback mux)
             |                 +-------------+
             |                   rs1_data, rs2_data
             |                        |
             |                        v
             |                 +-----------+
             |     alu_src_a-->|    ALU    |<--alu_src_b (rs2_data or imm_out)
             |                 +-----------+
             |                   result, zero
             |                        |
             |              +---------+---------+
             |              v                   v
             |       +-------------+     branch/jump target adders
             |       | data_memory |     (pc + imm, rs1 + imm for JALR)
             |       +-------------+
             |              |
             +--------------+---- pc_next select:
                                   jalr ? jalr_target :
                                   jump ? jal_target  :
                                   (branch & zero) ? branch_target :
                                   pc + 4
```

## Control signal reference

| Signal | Width | Meaning |
|---|---|---|
| `reg_write` | 1 | write `rd_data` into `rd` this cycle |
| `mem_read` | 1 | data_memory drives `read_data` (LW) |
| `mem_write` | 1 | data_memory commits `write_data` (SW) |
| `alu_src_a` | 1 | 0 = rs1, 1 = zero (LUI only) |
| `alu_src_b` | 1 | 0 = rs2, 1 = immediate |
| `alu_control` | 4 | 0000 ADD, 0001 SUB, 0010 AND, 0011 OR, 0100 XOR, 0101 PASSB (LUI) |
| `imm_type` | 3 | 000 I, 001 S, 010 B, 011 U, 100 J |
| `branch` | 1 | BEQ: combine with ALU `zero` for taken |
| `jump` | 1 | JAL |
| `jalr` | 1 | JALR |
| `result_src` | 2 | 00 = ALU result, 01 = mem data, 10 = PC+4 (link) |

## Opcode map (Phase 1 subset)

| Instr | opcode | funct3 | funct7 |
|---|---|---|---|
| ADD | 0110011 | 000 | 0000000 |
| SUB | 0110011 | 000 | 0100000 |
| AND | 0110011 | 111 | 0000000 |
| OR  | 0110011 | 110 | 0000000 |
| XOR | 0110011 | 100 | 0000000 |
| ADDI | 0010011 | 000 | — |
| LW | 0000011 | 010 | — |
| SW | 0100011 | 010 | — |
| BEQ | 1100011 | 000 | — |
| JAL | 1101111 | — | — |
| JALR | 1100111 | 000 | — |
| LUI | 0110111 | — | — |

## Known simplifications (fine for Phase 1, will matter later)

- Word-addressed data memory (no byte/halfword LB/LH/SB/SH yet) — fine
  since only LW/SW are in scope.
- No illegal-instruction trap; unrecognized opcodes fall through to the
  `default` case in `control_unit.v` and act as a NOP (no writes, PC+4).
- Instruction and data memory are separate arrays (Harvard-style), which
  conveniently is also what's needed once I-cache/D-cache split out in
  Phase 4 — no rework needed there.
