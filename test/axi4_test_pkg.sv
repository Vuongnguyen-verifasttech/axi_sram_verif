`timescale 1ns/1ps

package axi4_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import axi4_env_pkg::*;
    import axi4_seq_pkg::*;

    // Include test
    `include "axi4_base_test.sv"
    `include "axi4_reset_sanity_test.sv"
    `include "axi4_reset_during_write_test.sv"
    `include "axi4_reset_during_read_test.sv"
    `include "axi4_reset_during_burst_test.sv"

endpackage : axi4_test_pkg