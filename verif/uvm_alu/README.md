# UVM Testbench for the RV32I ALU

A SystemVerilog/UVM environment that verifies `rtl/alu.v` (ADD, SUB, AND, OR, XOR, PASSB) against an independent reference model, with constrained-random and directed corner-case stimulus and functional coverage.

## Architecture

```
alu_*_test
  └── alu_env
        ├── alu_agent
        │     ├── uvm_sequencer   ← alu_random_seq / alu_corner_seq
        │     ├── alu_driver      drives inputs on posedge clk
        │     └── alu_monitor     samples inputs + outputs on negedge clk
        ├── alu_scoreboard        reference model, checks result and zero flag
        └── alu_coverage          opcode × operand-class bins, zero flag per opcode
tb_top: clock, alu_if, DUT, zero-flag assertion, run_test()
```

The ALU is combinational, so the testbench supplies a clock: inputs change on the rising edge and are checked on the falling edge.

| File | Contents |
|---|---|
| `alu_if.sv` | Interface (operands, control, result, zero, valid) |
| `alu_pkg.sv` | Transaction, sequences, driver, monitor, agent, scoreboard, coverage, env, tests |
| `tb_top.sv` | Top module, DUT instance, assertion, `run_test()` |

## Stimulus

* **`alu_random_test`**: 2,000 constrained-random transactions. Opcodes are 90 % legal and 10 % unused encodings (the ALU must return 0). Operands are biased towards 0, 1, all-ones, 0x7FFFFFFF and 0x80000000, where carries, overflow and the zero flag usually go wrong.
* **`alu_corner_test`**: every one of the 16 opcodes against every pair of 7 corner values (784 directed transactions), followed by 500 random ones.

## Checks

* **Scoreboard**: compares `result` and `zero` with a reference model written from the RV32I spec, for every transaction.
* **Assertion** in `tb_top`: `zero` must always equal `(result == 0)`.

## Coverage

* 256 bins: 16 opcodes × 4 operand-A classes × 4 operand-B classes (zero, all-ones, sign boundary, other).
* 12 bins: zero flag 0/1 for each of the 6 legal opcodes.

Coverage is counted inside the subscriber (not a covergroup), so the percentage prints on any simulator.

## Results

Run with Verilator 5.054 and UVM 2017 (Verilator-compatible build).

| Test | Transactions | Mismatches | Opcode × operand coverage | Zero-flag coverage | Result |
|---|---|---|---|---|---|
| `alu_random_test` | 2,000 | 0 | 55.1 % | 100 % | PASS |
| `alu_corner_test` | 1,284 | 0 | **100 %** | 100 % | PASS |

Random stimulus alone leaves the rarer bins (unused opcodes with corner operands) uncovered, so the directed corner sequence closes them.

**Bug-injection check:** to confirm the testbench actually catches bugs, SUB was changed to `a + ~b` (missing the +1 of two's complement) in a copy of the ALU. The scoreboard flagged it on the 2nd transaction and reported 300 mismatches out of 2,000 (every SUB), and the test failed. To reproduce:

```bash
sed 's/operand_a - operand_b/operand_a + ~operand_b/' ../../rtl/alu.v > /tmp/alu_bug.v
# then build with /tmp/alu_bug.v in place of ../../rtl/alu.v
```

## How to run

**Vivado (xsim), Windows:** open the Vivado Tcl shell or a command prompt with Vivado on the PATH, `cd` into this folder, then:

```
run_xsim.bat alu_corner_test
```

**Vivado (xsim), Linux/WSL:** `./run_xsim.sh alu_corner_test`

**Verilator 5.04x + UVM:** `make TEST=alu_corner_test UVM_HOME=/path/to/uvm/src`

**EDA Playground (browser, free login):** paste `rtl/alu.v` in *design.sv*; in *testbench.sv* put `` `include "alu_if.sv" `` and `` `include "alu_pkg.sv" `` followed by the contents of `tb_top.sv` (add the two files as extra tabs). Select *UVM 1.2* and Aldec Riviera-PRO or Synopsys VCS, and set run options to `+UVM_TESTNAME=alu_corner_test`.
