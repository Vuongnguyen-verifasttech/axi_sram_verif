`timescale 1ns/1ps

// =============================================================================
// axi4_virtual_seqr.sv
// Virtual Sequencer - cho phép test spawn sequence trên các channel riêng
// =============================================================================

class axi4_virtual_seqr extends uvm_sequencer;

    // =========================================================================
    // References đến sequencer thực tế trong agent
    // =========================================================================
    uvm_sequencer #(axi4_wr_seq_item) wr_seqr;
    uvm_sequencer #(axi4_rd_seq_item) rd_seqr;

    // =========================================================================
    // UVM
    // =========================================================================
    `uvm_component_utils(axi4_virtual_seqr)

    function new(string name = "axi4_virtual_seqr", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =========================================================================
    // Build Phase
    // =========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Sequencers được assign từ environment
    endfunction

endclass : axi4_virtual_seqr
