# Simulation & Regression Flow Guide

## Overview

This document describes the standard simulation, sanity, and regression flow for the AXI4 UVM verification environment.

---

# Make Targets

| Target            | Purpose                                 |
| ----------------- | --------------------------------------- |
| `make compile`    | Compile RTL and Testbench               |
| `make sim`        | Run a single testcase                   |
| `make run`        | Run multiple testcases                  |
| `make regression` | Run full regression with multiple seeds |
| `make merge`      | Merge coverage databases                |
| `make report`     | Generate coverage reports               |
| `make wave`       | Launch GUI waveform debug               |
| `make clean`      | Clean generated files                   |

---

# 1. Compile

Compile RTL and verification environment.

```bash
make compile
```

Generated artifacts:

```text
work/
compile.log
```

---

# 2. Single Test Simulation

Run a single testcase for debugging.

```bash
make sim TESTNAME=axi4_write_test
```

Example:

```bash
make sim TESTNAME=axi4_read_test
```

Typical usage:

* Debug sequence
* Debug driver/monitor
* Debug scoreboard
* Debug DUT functionality

Flow:

```text
Compile
   ↓
Run 1 Test
   ↓
Simulation Log
```

---

# 3. Multiple Test Execution (Sanity)

Run a selected set of testcases.

```bash
make run TEST_LIST="axi4_write_test axi4_read_test axi4_burst_test"
```

Example:

```bash
make run TEST_LIST="axi4_base_test axi4_write_test"
```

Typical usage:

* Pre-commit validation
* Sanity checking
* Quick verification after feature updates

Flow:

```text
Compile
   ↓
Run Test 1
Run Test 2
Run Test 3
   ↓
Simulation Logs
```

Coverage collection is optional.

---

# 4. Full Regression

Run all regression tests with multiple random seeds.

```bash
make regression NUM_SEEDS=20
```

Example:

```bash
make regression NUM_SEEDS=10
```

Typical usage:

* Nightly regression
* Milestone verification
* Coverage closure

Flow:

```text
Compile
   ↓
All Regression Tests
   ↓
Multiple Seeds
   ↓
UCDB Coverage Files
```

Example:

```text
axi4_write_test
 ├─ seed1
 ├─ seed2
 ├─ seed3
 └─ seed10

axi4_read_test
 ├─ seed1
 ├─ seed2
 └─ seed10
```

Generated artifacts:

```text
cov/
regression_logs/
```

---

# 5. Coverage Merge

Merge all generated UCDB files.

```bash
make merge
```

Flow:

```text
test1_seed1.ucdb
test1_seed2.ucdb
test2_seed1.ucdb
...
        ↓
merged.ucdb
```

Generated artifact:

```text
cov/merged.ucdb
```

---

# 6. Coverage Report Generation

Generate HTML and text coverage reports.

```bash
make report
```

Generated artifacts:

```text
coverage_report/
coverage_summary.txt
```

Output includes:

* Code Coverage
* Functional Coverage
* Coverage Summary
* Coverage Details

---

# 7. Waveform Debug

Launch QuestaSim GUI with waveform view.

```bash
make wave TESTNAME=axi4_write_test
```

Typical usage:

* Protocol debugging
* Timing analysis
* Signal inspection

Flow:

```text
Simulation
   ↓
Waveform Viewer
   ↓
Debug
```

---

# 8. Clean Workspace

Remove generated simulation artifacts.

```bash
make clean
```

Removed items:

```text
work/
transcript
vsim.wlf

compile.log
sim.log

logs/
regression_logs/

cov/
coverage_report/

*.ucdb
```

---

# Recommended Daily Workflow

## During Development

Run and debug a single testcase:

```bash
make sim TESTNAME=axi4_write_test
```

---

## Before Commit

Run sanity tests:

```bash
make run TEST_LIST="axi4_base_test axi4_write_test axi4_read_test"
```

Verify:

* No failures
* No scoreboard mismatches
* No protocol violations

---

## Before Merge / End of Day

Run regression:

```bash
make regression NUM_SEEDS=10
```

Merge coverage:

```bash
make merge
```

Generate report:

```bash
make report
```

Review:

* Pass Rate
* Functional Coverage
* Code Coverage
* Coverage Holes

---

# Verification Flow Summary

```text
Development
    ↓
Single Test Debug
    ↓
Sanity Run
    ↓
Regression
    ↓
Coverage Merge
    ↓
Coverage Report
    ↓
Coverage Closure
```
