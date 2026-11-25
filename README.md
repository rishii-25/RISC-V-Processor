# RV32I Single-Cycle Processor — Phase 1

32-bit RISC-V (RV32I) processor project. This is **Phase 1** of the full
roadmap: a working single-cycle core, verified, as the baseline the
5-stage pipeline (Phase 2+) will be built from and checked against.

## Status

**Phase 1: done, all 19 testbench checks pass.**

| Phase | Status |
|---|---|
| 1. Single-cycle CPU | ✅ done |
| 2. Five-stage pipeline | not started |
| 3. Hazard detection / forwarding | not started |
| 4. I-cache / D-cache | not started |
| 5. Branch prediction | not started |
| 6. Verification & benchmarks | ongoing: Phase 1 tb + UVM ALU testbench ([verif/uvm_alu](verif/uvm_alu)) |
| 7. Synthesis (Yosys/OpenSTA/OpenROAD) + FPGA | not started |

## Instruction set implemented

`ADD, SUB, ADDI, AND, OR, XOR, LW, SW, BEQ, JAL, JALR, LUI`

JALR was added to the originally planned subset (ADD/SUB/ADDI, AND/OR/XOR,
LW/SW, BEQ/JAL, LUI) since it shares the I-type immediate path already
needed for ADDI/LW, and is needed for any real function-call test program
later on — cheap to add now, awkward to retrofit once the pipeline exists.

## Layout

```
riscv-processor/
├── rtl/
│   ├── riscv_top.v              top-level, wires everything together
│   ├── program_counter.v        PC register
│   ├── instruction_memory.v     ROM, loaded from programs/*.hex
│   ├── control_unit.v           opcode/funct3/funct7 -> control signals
│   ├── register_file.v          32 x 32-bit regs, x0 hardwired to 0
│   ├── immediate_generator.v    I/S/B/U/J immediate decode
│   ├── alu.v                    ADD/SUB/AND/OR/XOR/PASSB
│   └── data_memory.v            word-addressed RAM for LW/SW
├── tb/
│   └── tb_riscv_top.v           self-checking testbench (19 checks)
├── programs/
│   └── test_program.hex         assembled test program (23 instructions)
├── sim/
│   └── assemble.py              tiny hand-assembler that generates the .hex
├── docs/
│   └── architecture.md          datapath notes, control signal reference
└── Makefile
```

## Running it

Requires `iverilog` and (optionally) `gtkwave` — both already installed
in this environment via `apt-get install iverilog gtkwave`.

```bash
make sim      # compile + run the testbench, prints PASS/FAIL per check
make wave     # open the waveform in GTKWave
make clean    # remove build artifacts
```

To change the test program: edit the instruction list in
`sim/assemble.py`, then `make assemble` (regenerates the `.hex`) and
`make sim`.

## Design notes

- **Timing model**: everything from fetch through writeback happens
  combinationally within one clock period; only the PC, register file,
  and data memory are stateful. This is intentionally the simplest
  correct implementation — Phase 2 will cut it at the IF/ID/EX/MEM/WB
  boundaries and insert pipeline registers.
- **Register file reads/writes**: reads are asynchronous (combinational),
  writes commit on the clock edge. This is what makes single-cycle
  semantics correct — each instruction's register reads reflect the
  state *before* its own writeback.
- **Branch resolution**: BEQ reuses the ALU in SUB mode; branch taken =
  `zero` flag high. No separate comparator.
- **x0**: hardwired to zero in both the read muxes and the write path
  (writes to x0 are silently discarded), per spec.
- The `$readmemh` warning about "not enough words" on simulation start
  is expected and harmless — the instruction ROM is sized at 256 words
  so later, longer test programs don't need the parameter changed; the
  unused words are simply zero.

## Next step (Phase 2)

Pipeline registers (`if_id.v`, `id_ex.v`, `ex_mem.v`, `mem_wb.v`) between
the five stages, using this module's control/datapath signals as the
per-stage payload. The same `test_program.hex` and the same expected
register values in the testbench should hold for the pipelined version —
that's the correctness cross-check between Phase 1 and Phase 2.
