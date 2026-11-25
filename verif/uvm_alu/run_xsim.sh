#!/usr/bin/env bash
# Run the ALU UVM testbench with Vivado's simulator (xsim) on Linux/WSL.
# Usage: ./run_xsim.sh [alu_random_test | alu_corner_test]
set -e
TEST=${1:-alu_random_test}
xvlog ../../rtl/alu.v
xvlog -sv -L uvm alu_if.sv alu_pkg.sv tb_top.sv
xelab tb_top -L uvm -timescale 1ns/1ps -s alu_sim
xsim alu_sim -R -testplusarg UVM_TESTNAME=$TEST -log $TEST.log
