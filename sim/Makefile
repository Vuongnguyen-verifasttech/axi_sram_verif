# =============================================================================
# Makefile cho AXI4 SRAM UVM Environment
# =============================================================================

SIM_TOOL   ?= vcs        # vcs / xrun / questa
TOP        ?= tb_top
TESTNAME   ?= axi4_base_test     # sẽ thay đổi sau
UVM_VER    ?= uvm-1.2

# Common flags
COMMON_FLAGS = -sverilog +acc +v2k -timescale=1ns/1ps \
               -ntb_opts uvm=$(UVM_VER) \
               -lca -debug_access+all -kdb

# Filelist
RTL_F  = filelist/rtl.f
TB_F   = filelist/tb.f

compile:
	@echo "=== Compiling AXI4 SRAM UVM ==="
	$(SIM_TOOL) -top $(TOP) \
		-f $(RTL_F) \
		-f $(TB_F) \
		$(COMMON_FLAGS) \
		-l compile.log

run: compile
	@echo "=== Running test: $(TESTNAME) ==="
	./simv +UVM_TESTNAME=$(TESTNAME) \
	       +UVM_VERBOSITY=UVM_MEDIUM \
	       -l sim.log

clean:
	rm -rf simv* csrc* *.log *.vcd *.fsdb *.db *.vpd ucli.key

# Quick run
test: clean run

.PHONY: compile run clean test