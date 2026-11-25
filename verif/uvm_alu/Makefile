# Verilator (>= 5.04x) flow for the ALU UVM testbench.
# Needs: an SMT solver for constrained randomization (sudo apt install z3) and a
# Verilator-compatible UVM library, e.g. https://github.com/antmicro/uvm-verilator
#   make UVM_HOME=/path/to/uvm-verilator/src TEST=alu_corner_test

UVM_HOME ?= $(HOME)/uvm-verilator/src
TEST     ?= alu_random_test
OBJ      := obj_dir

SRCS := $(UVM_HOME)/uvm_pkg.sv ../../rtl/alu.v alu_if.sv alu_pkg.sv tb_top.sv

.PHONY: run build clean

run: $(OBJ)/Vtb_top
	./$(OBJ)/Vtb_top +UVM_TESTNAME=$(TEST)

$(OBJ)/Vtb_top: $(SRCS)
	verilator --binary -j 0 --timing --top-module tb_top -Mdir $(OBJ) \
	  -Wno-fatal -Wno-lint -Wno-style +define+UVM_NO_DPI \
	  +incdir+$(UVM_HOME) $(SRCS)

build: $(OBJ)/Vtb_top

clean:
	rm -rf $(OBJ) *.log xsim.dir *.jou *.pb *.wdb .Xil
