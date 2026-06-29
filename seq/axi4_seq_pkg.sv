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
   
   // RESET SEQUENCE
    `include "../seq/sequences/axi4_reset_seq.sv"
    `include "../seq/sequences/axi4_reset_sanity_seq.sv"
    
    `include "../seq/sequences/axi4_reset_during_write_seq.sv"
     `include "../seq/sequences/axi4_reset_during_read_seq.sv"
     `include "../seq/sequences/axi4_reset_during_burst_seq.sv"
     `include "../seq/sequences/axi4_random_reset_stress_seq.sv"
     `include "../seq/sequences/axi4_incr_burst_wr_seq.sv"
      `include "../seq/sequences/axi4_incr_burst_rd_seq.sv" 
       `include "../seq/sequences/axi4_fixed_burst_seq.sv"
      `include "../seq/sequences/axi4_wrap_burst_seq.sv"
      `include "../seq/sequences/axi4_concurrent_rw_seq.sv"
      `include "../seq/sequences/axi4_concurrent_rw_bug_seq.sv"
      `include "../seq/sequences/axi4_backpressure_seq.sv"
      
      `include "../seq/sequences/axi4_multi_outstanding_seq.sv"

      `include "../seq/sequences/axi4_random_mixed_seq.sv"
      `include "../seq/sequences/axi4_rtl_bug001_seq.sv"
      
 



endpackage : axi4_seq_pkg
