`timescale 1ns/1ps

package axi4_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import axi4_env_pkg::*;

    // Include sequence trước test
    `include "../seq/base/axi4_base_seq.sv"

    // Include test
    `include "axi4_base_test.sv"

endpackage : axi4_test_pkg