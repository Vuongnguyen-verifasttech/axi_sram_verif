# =============================================
# Makefile cho AXI UVM Verification (QuestaSim 10.6b)
# =============================================

TOP_MODULE   = tb_top
FILELIST     = run.f

# Coverage (nếu sau này cần)
COV_COMPILE  = -cover bcesf
COV_SIM      = -coverage

# =============================================
# Main Targets
# =============================================

all: clean compile run

# Khởi tạo library
init:
	vlib work
	vmap work work

# Compile
compile:
	vlog -work work -sv -mfcu -timescale=1ns/1ps +acc \
		+incdir+../axi_lib/include \
		+incdir+../axi_lib/src \
		+incdir+../tb \
		$(COV_COMPILE) \
		-f $(FILELIST)

# Simulation console (không wave)
sim:
	vsim -c -suppress 3009 \
		$(TOP_MODULE) \
		-do "run -all; quit -f"

# Debug - Mở GUI + Wave (quan trọng nhất lúc này)
debug: gui

gui:
	vsim -voptargs="+acc" -suppress 3009 \
		$(TOP_MODULE) \
		-do " \
			add wave -r /*; \
			run -all; \
		"

# Clean
clean:
	rm -rf work transcript vsim.wlf modelsim.ini *.log *.vcd *.wlf *.ucdb \
	       *.cov *.html covhtml* regression_logs
	@echo "=== Clean completed! ==="

# =============================================
# Utility
# =============================================

re: clean compile sim

# Chạy nhanh chỉ compile + sim console
run: clean compile sim

# Help
help:
	@echo "Available targets:"
	@echo "  make compile     - Compile design"
	@echo "  make sim         - Run simulation in console"
	@echo "  make debug / gui - Run with GUI + Waveform"
	@echo "  make clean       - Clean everything"
	@echo "  make all         - Clean + Compile + Run"
	@echo "  make re          - Rebuild and run console"

.PHONY: all init compile sim debug gui clean run re help