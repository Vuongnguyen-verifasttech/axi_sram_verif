# =============================================================================
# AXI4 UVM Makefile - QuestaSim 10.6b
# =============================================================================

TOP        ?= tb_top
TESTNAME   ?= axi4_base_test

RTL_F      = filelist/rtl.f
TB_F       = filelist/tb.f

# =============================================================================
# Coverage
# =============================================================================
COV_COMPILE   = -cover bcesf
COV_SIM       = -coverage

COV_DIR       = cov_merge
COV_REPORT    = coverage_report

# =============================================================================
# Regression Configuration
# =============================================================================

TEST_LIST ?= \
	axi4_base_test \
	axi4_write_test \
	axi4_read_test \
	axi4_burst_test \
	axi4_reset_test

NUM_SEEDS ?= 1

# =============================================================================
# Main Flow
# =============================================================================

all: clean compile run_regression merge_coverage report

# =============================================================================
# Compile
# =============================================================================

compile:
	@echo "=== Compiling Design & TB ==="
	vlib work
	vmap work work

	vlog -sv +acc \
		-timescale=1ns/1ps \
		+define+UVM \
		$(COV_COMPILE) \
		-f $(RTL_F) \
		-f $(TB_F) \
		-l compile.log \
		-suppress 2181,2218,2220

# =============================================================================
# Single Test Run
# Example:
# make sim TESTNAME=axi4_write_test
# =============================================================================

sim: compile
	@mkdir -p single_run_logs

	vsim -c \
		$(COV_SIM) \
		work.$(TOP) \
		+UVM_TESTNAME=$(TESTNAME) \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-do "run -all; coverage save -onexit $(TESTNAME).ucdb; quit -f" \
		| tee single_run_logs/$(TESTNAME).log

# =============================================================================
# GUI + Wave
# Example:
# make wave TESTNAME=axi4_write_test
# =============================================================================

wave: compile
	vsim \
		work.$(TOP) \
		+UVM_TESTNAME=$(TESTNAME) \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-do "add wave -r /*; run -all"

# =============================================================================
# Regression
# =============================================================================

run_regression:
	@echo "==============================================="
	@echo " Running Regression"
	@echo "==============================================="

	@mkdir -p regression_logs
	@mkdir -p $(COV_DIR)

	@for test in $(TEST_LIST); do \
		echo ""; \
		echo ">>> Running $$test"; \
		for seed in $$(seq 1 $(NUM_SEEDS)); do \
			echo "    Seed $$seed"; \
			vsim -c \
				$(COV_SIM) \
				work.$(TOP) \
				+UVM_TESTNAME=$$test \
				+UVM_SEED=$$seed \
				-do "run -all; coverage save -onexit $(COV_DIR)/$${test}_seed$$seed.ucdb; quit -f" \
				> regression_logs/$${test}_seed$$seed.log 2>&1; \
		done; \
	done

# =============================================================================
# Coverage Merge
# =============================================================================

merge_coverage:
	@echo "=== Merging Coverage ==="

	@rm -f $(COV_DIR)/merged.ucdb

	@if ls $(COV_DIR)/*.ucdb >/dev/null 2>&1; then \
		vcover merge \
			-out $(COV_DIR)/merged.ucdb \
			$(COV_DIR)/*.ucdb; \
	else \
		echo "No UCDB files found"; \
		exit 1; \
	fi

# =============================================================================
# Coverage Report
# =============================================================================

report:
	@echo "=== Generating Coverage Report ==="

	vcover report \
		-html \
		-htmldir $(COV_REPORT) \
		-details \
		$(COV_DIR)/merged.ucdb

	vcover report \
		-details \
		$(COV_DIR)/merged.ucdb \
		> coverage_summary.txt

# =============================================================================
# Quick Commands
# =============================================================================

run: sim

test: clean sim

# =============================================================================
# Clean
# =============================================================================

clean:
	@echo "=== Cleaning ==="

	rm -rf work
	rm -rf transcript
	rm -rf vsim.wlf

	rm -rf regression_logs
	rm -rf single_run_logs

	rm -rf $(COV_DIR)
	rm -rf $(COV_REPORT)

	rm -f *.ucdb
	rm -f *.log
	rm -f coverage_summary.txt

.PHONY: \
	all \
	compile \
	sim \
	wave \
	run \
	test \
	run_regression \
	merge_coverage \
	report \
	clean