@echo off
REM Run the ALU UVM testbench with Vivado's simulator (xsim), from this folder.
REM Usage: run_xsim.bat [alu_random_test | alu_corner_test]
set TEST=%1
if "%TEST%"=="" set TEST=alu_random_test

call xvlog ../../rtl/alu.v || goto :err
call xvlog -sv -L uvm alu_if.sv alu_pkg.sv tb_top.sv || goto :err
call xelab tb_top -L uvm -timescale 1ns/1ps -s alu_sim || goto :err
call xsim alu_sim -R -testplusarg UVM_TESTNAME=%TEST% -log %TEST%.log
goto :eof
:err
echo Compile failed.
