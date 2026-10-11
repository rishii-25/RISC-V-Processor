# Makefile for the single-cycle RV32I core (Phase 1).

RTL = rtl/program_counter.v rtl/instruction_memory.v rtl/register_file.v \
      rtl/immediate_generator.v rtl/alu.v rtl/data_memory.v \
      rtl/control_unit.v rtl/riscv_top.v

TB  = tb/tb_riscv_top.v

SIM_OUT = sim/riscv_sim.out
VCD     = sim/tb_riscv_top.vcd
PROGRAM = programs/test_program.hex

.PHONY: all sim wave clean assemble

all: sim

$(PROGRAM): sim/assemble.py
	python3 sim/assemble.py $(PROGRAM)

assemble: $(PROGRAM)

$(SIM_OUT): $(RTL) $(TB) $(PROGRAM)
	iverilog -g2012 -o $(SIM_OUT) $(RTL) $(TB)

sim: $(SIM_OUT)
	vvp $(SIM_OUT)

wave: sim
	gtkwave $(VCD) &

clean:
	rm -f $(SIM_OUT) $(VCD)
