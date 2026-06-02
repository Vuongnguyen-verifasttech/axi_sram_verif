# =============================================================================
# Makefile cho AXI4 SRAM UVM Environment - Dành cho QuestaSim
# =============================================================================

SIM_TOOL   ?= questa        # questa / vcs
TOP        ?= tb_top
TESTNAME   ?= axi4_base_test
UVM_VER    ?= uvm-1.2

# Common flags
COMMON_FLAGS = -sv +acc -timescale=1ns/1ps \
               +define+UVM \
               -l compile.log

# Questa specific
QUESTA_FLAGS = -uvm -work work -suppress 2181

# Filelist
RTL_F  = filelist/rtl.f
TB_F   = filelist/tb.f

# =============================================================================
compile:
	@echo "=== Compiling AXI4 SRAM UVM with QuestaSim ==="
	vlib work
	vlog -f $(RTL_F) \
	     -f $(TB_F) \
	     $(COMMON_FLAGS) \
	     $(QUESTA_FLAGS)

run: compile
	@echo "=== Running test: $(TESTNAME) ==="
	vsim -c -do "run -all; quit -f" \
	     +UVM_TESTNAME=$(TESTNAME) \
	     +UVM_VERBOSITY=UVM_MEDIUM \
	     work.$(TOP) \
	     -l sim.log

# Quick commands
test: clean run

clean:
	rm -rf work/ transcript vsim.wlf *.log *.vcd *.fsdb *.db

.PHONY: compile run clean test