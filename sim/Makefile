# =============================================================================
# Makefile cho QuestaSim 10.6b
# =============================================================================

TOP        ?= tb_top
TESTNAME   ?= axi4_base_test

RTL_F  = filelist/rtl.f
TB_F   = filelist/tb.f

compile:
	@echo "=== Compiling with QuestaSim ==="
	vlib work
	vlog -sv +acc -timescale=1ns/1ps +define+UVM \
	     -f $(RTL_F) \
	     -f $(TB_F) \
	     -l compile.log \
	     -suppress 2181,2218,2220

run: compile
	@echo "=== Running $(TESTNAME) ==="
	vsim -c -do "run -all; quit -f" \
	     +UVM_TESTNAME=$(TESTNAME) \
	     +UVM_VERBOSITY=UVM_MEDIUM \
	     work.$(TOP) \
	     -l sim.log

test: clean run

clean:
	rm -rf work/ transcript vsim.wlf *.log

.PHONY: compile run clean test