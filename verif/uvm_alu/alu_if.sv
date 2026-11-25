// alu_if.sv
// Interface between the UVM testbench and the combinational ALU.
// The ALU has no clock, so the testbench supplies one: the driver applies
// inputs on the rising edge and the monitor samples on the falling edge,
// giving the combinational logic half a cycle to settle.

interface alu_if (input logic clk);
    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [3:0]  alu_control;
    logic [31:0] result;
    logic        zero;
    logic        valid;   // high when the driver has applied a transaction
endinterface
