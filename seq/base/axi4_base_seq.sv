
`timescale 1ns/1ps

// =============================================================================
// axi4_base_seq.sv
// Base Virtual Sequence
// =============================================================================

class axi4_base_seq extends uvm_sequence;

    `uvm_object_utils(axi4_base_seq)

    // =========================================================================
    // Virtual Sequencer Handle
    // =========================================================================

    axi4_virtual_seqr vseqr;

    // =========================================================================
    // Constructor
    // =========================================================================

    function new(string name = "axi4_base_seq");
        super.new(name);
    endfunction

    // =========================================================================
    // Body
    // =========================================================================

    virtual task body();

        if (!$cast(vseqr, m_sequencer)) begin
            `uvm_fatal(get_type_name(),
                       "Cannot cast m_sequencer to axi4_virtual_seqr")
        end

        `uvm_info(get_type_name(),
                  "Virtual sequencer acquired",
                  UVM_LOW)

    endtask

    // =========================================================================
    // Common Utility Tasks
    // =========================================================================

    virtual task run_single_write();

        axi4_single_wr_seq seq;

        seq = axi4_single_wr_seq::type_id::create("seq");

        seq.start(vseqr.wr_seqr);

    endtask

    virtual task run_single_read();

        axi4_single_rd_seq seq;

        seq = axi4_single_rd_seq::type_id::create("seq");

        seq.start(vseqr.rd_seqr);

    endtask

    virtual task run_integrity_test();

        axi4_wr_rd_integrity_seq seq;

        seq = axi4_wr_rd_integrity_seq::type_id::create("seq");

        seq.start(vseqr);

    endtask

endclass : axi4_base_seq

