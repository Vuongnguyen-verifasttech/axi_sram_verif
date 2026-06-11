`timescale 1ns/1ps

// =============================================================================
// axi4_base_seq.sv
// Base sequence - Spawn write and read sequences on virtual sequencer
// =============================================================================

class axi4_base_seq extends uvm_sequence;

    `uvm_object_utils(axi4_base_seq)

    // Constructor
    function new(string name = "axi4_base_seq");
        super.new(name);
    endfunction

    // =========================================================================
    // Virtual sequencer reference
    // =========================================================================
    axi4_virtual_seqr vseqr;

    // =========================================================================
    // Main body task
    // =========================================================================
    virtual task body();
        `uvm_info(get_type_name(), "Starting axi4_base_seq", UVM_LOW)

        // Lấy virtual sequencer từ sequencer hiện tại
        if (!$cast(vseqr, m_sequencer)) begin
            `uvm_error(get_type_name(), "Cannot cast m_sequencer to axi4_virtual_seqr")
            return;
        end

        // Reset
        do_reset();

        // Write sequences
        fork
            repeat(2) run_single_write();
        join

        // Read sequences
        fork
            repeat(2) run_single_read();
        join

        // Write then read integrity test
        write_read_integrity_test();

        `uvm_info(get_type_name(), "axi4_base_seq completed", UVM_LOW)
    endtask

    // =========================================================================
    // Utility tasks
    // =========================================================================
    virtual task do_reset();
        `uvm_info(get_type_name(), "Applying reset sequence", UVM_MEDIUM)
        #100ns;
    endtask

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

    virtual task write_read_integrity_test();
        axi4_wr_seq_item wr_item;
        axi4_rd_seq_item rd_item;

        // Write item
        wr_item = axi4_wr_seq_item::type_id::create("wr_item");
        if (!wr_item.randomize()) begin
            `uvm_error(get_type_name(), "Failed to randomize wr_item")
        end

        // Read item  
        rd_item = axi4_rd_seq_item::type_id::create("rd_item");
        if (!rd_item.randomize() with { araddr == wr_item.awaddr; }) begin
            `uvm_error(get_type_name(), "Failed to randomize rd_item")
        end

        `uvm_info(get_type_name(), "Write-Read integrity test: WR_ADDR=0x%0h RD_ADDR=0x%0h", 
                  wr_item.awaddr, rd_item.araddr, UVM_MEDIUM)
    endtask

endclass : axi4_base_seq