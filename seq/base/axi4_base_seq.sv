`timescale 1ns/1ps

// =============================================================================
// axi4_base_seq.sv
// Base sequence - Chứa các hành vi cơ bản cho tất cả sequence
// =============================================================================

import axi4_agent_pkg::*;

class axi4_base_seq extends uvm_sequence #(axi4_transaction);

    `uvm_object_utils(axi4_base_seq)

    // Constructor
    function new(string name = "axi4_base_seq");
        super.new(name);
    endfunction

    // =====================================================================
    // Main body task
    // =====================================================================
    virtual task body();
        `uvm_info(get_type_name(), "Starting axi4_base_seq", UVM_LOW)

        // Step 1: Reset
        do_reset();

        // Step 2: Một số transaction cơ bản để test env + scoreboard
        repeat(3) begin
            single_write();
        end

        repeat(3) begin
            single_read();
        end

        // Step 3: Write then Read same address (data integrity check)
        write_read_integrity_test();

        `uvm_info(get_type_name(), "axi4_base_seq completed", UVM_LOW)
    endtask

    // =====================================================================
    // Utility tasks
    // =====================================================================
    virtual task do_reset();
        `uvm_info(get_type_name(), "Applying reset sequence", UVM_MEDIUM)
        // Hiện tại reset được xử lý bởi clk_rst_gen, sequence chỉ chờ
        #100ns;
    endtask

    virtual task single_write();
        axi4_transaction tr = axi4_transaction::type_id::create("tr_write");
        
        start_item(tr);
        assert(tr.randomize() with {
            is_write == 1;
            len == 0;           // single beat
            burst == 2'b01;     // INCR
        });
        finish_item(tr);
    endtask

    virtual task single_read();
        axi4_transaction tr = axi4_transaction::type_id::create("tr_read");
        
        start_item(tr);
        assert(tr.randomize() with {
            is_write == 0;
            len == 0;
            burst == 2'b01;
        });
        finish_item(tr);
    endtask

    virtual task write_read_integrity_test();
        axi4_transaction tr_wr = axi4_transaction::type_id::create("tr_wr");
        axi4_transaction tr_rd = axi4_transaction::type_id::create("tr_rd");
        
        // Write
        start_item(tr_wr);
        assert(tr_wr.randomize() with { is_write == 1; len == 0; });
        finish_item(tr_wr);

        // Read same address
        start_item(tr_rd);
        assert(tr_rd.randomize() with {
            is_write == 0;
            len == 0;
            araddr == tr_wr.awaddr;
        });
        finish_item(tr_rd);
    endtask

endclass : axi4_base_seq