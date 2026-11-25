// tb_top.sv
// Top-level for the ALU UVM testbench: clock, interface, DUT, and run_test().
// Select a test with +UVM_TESTNAME=alu_random_test (default) or alu_corner_test.

`timescale 1ns/1ps

module tb_top;
    import uvm_pkg::*;
    import alu_pkg::*;
    `include "uvm_macros.svh"

    logic clk = 1'b0;
    always #5 clk = ~clk;

    alu_if vif (clk);

    alu dut (
        .operand_a   (vif.operand_a),
        .operand_b   (vif.operand_b),
        .alu_control (vif.alu_control),
        .result      (vif.result),
        .zero        (vif.zero)
    );

    // Immediate assertion on the zero flag: it must always mirror the result.
    always @(negedge clk)
        if (vif.valid)
            assert (vif.zero == (vif.result == 32'h0))
            else `uvm_error("ASSERT", $sformatf("zero=%0b but result=%08h", vif.zero, vif.result))

    initial begin
        uvm_config_db#(virtual alu_if)::set(null, "*", "vif", vif);
        run_test("alu_random_test");
    end
endmodule
