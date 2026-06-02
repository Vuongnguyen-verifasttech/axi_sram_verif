`timescale 1ns/1ps

// =============================================================================
// axi4_test_pkg.sv
// Package gom tất cả testcase
// =============================================================================

package axi4_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import environment package
    import axi4_env_pkg::*;

    // Include tất cả test
    `include "axi4_base_test.sv"

    // Các test khác sẽ include sau
    // `include "axi4_smoke_test.sv"
    // `include "axi4_regression_test.sv"

endpackage : axi4_test_pkg