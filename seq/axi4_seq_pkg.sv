`timescale 1ns/1ps

// =============================================================================
// axi4_seq_pkg.sv
// Package chứa tất cả sequence và virtual sequencer
// =============================================================================

package axi4_seq_pkg;

    import uvm_pkg::*;
    import axi4_vseqr_pkg::*;
    `include "uvm_macros.svh"
    
    import axi4_agent_pkg::*;

    // =====================================================================
    // Virtual Sequencer (giúp test spawn sequence trên multiple channels)
    // =====================================================================
   // `include "axi4_virtual_seqr.sv"

    // =====================================================================
    // Base Sequences (virtual tasks cho write/read)
    // =====================================================================
   

    `include "../seq/sequences/axi4_single_write_seq.sv"
    //`include "sequences/axi_incr_burst_seq.sv"
   // `include "sequences/axi_wrap_burst_seq.sv"

    // =====================================================================
    // Specific Read Sequences
    // =====================================================================
    `include "../seq/sequences/axi4_single_read_seq.sv"
    `include "../seq/sequences/axi4_wr_rd_integrity_seq.sv"
    `include "../seq/base/axi4_base_seq.sv"

    // =====================================================================
    // Mixed Sequences
    // =====================================================================
   // `include "sequences/axi_random_mixed_seq.sv"
    //`include "sequences/axi_concurrent_rw_seq.sv"

    // =====================================================================
    // Reset Sequence
    // =====================================================================
    //`include "sequences/axi4_reset_seq.sv"



endpackage : axi4_seq_pkg
