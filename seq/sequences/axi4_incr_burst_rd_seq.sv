`timescale 1ns/1ps

// =============================================================================
// axi4_incr_burst_rd_seq.sv
// AXI_06 - INCR Burst Read
//
// Flow:
//   1. Write N burst lên các địa chỉ random (dùng incr_burst_wr_seq)
//   2. Read lại đúng các địa chỉ đó với cùng awlen
//   3. Scoreboard tự verify data + in bảng per-beat
// =============================================================================

class axi4_incr_burst_rd_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_incr_burst_rd_seq)

    int unsigned n_trans = 20;

    function new(string name = "axi4_incr_burst_rd_seq");
        super.new(name);
    endfunction

    virtual task body();

        axi4_wr_seq_item   wr_req;
        axi4_rd_seq_item   rd_req;
        axi4_single_wr_seq wr_seq;
        axi4_single_rd_seq rd_seq;

        super.body();

        `uvm_info(get_type_name(),
            $sformatf("START INCR Burst Read: %0d transactions", n_trans),
            UVM_LOW)

        repeat (n_trans) begin

            // ------------------------------------------------------------------
            // Step 1: Write trước để có data trong SRAM
            // ------------------------------------------------------------------
            wr_req = axi4_wr_seq_item::type_id::create("wr_req");

            if (!wr_req.randomize() with {
                    awburst == 2'b01;
                    awlen   inside {[1:15]};   // giới hạn 16 beats để test nhanh
                    awaddr  % 4 == 0;
                    wdata.size() == awlen + 1;
                    // Giu TOAN BO burst trong SRAM 4KB. SRAM index bang
                    // addr[11:2] nen dia chi vuot 0xFFF se ALIAS vong ve vung
                    // thap -> burst wrap, ghi de, integrity check phu thuoc
                    // aliasing. Read thua huong range nay qua araddr==awaddr,
                    // arlen==awlen.
                    awaddr + (awlen + 1) * 4 <= 32'h0000_1000;
                })
                `uvm_fatal(get_type_name(), "WR Randomization failed")

            wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
            wr_seq.req = wr_req;
            wr_seq.start(vseqr.wr_seqr);

            // ------------------------------------------------------------------
            // Step 2: Read lại cùng địa chỉ, cùng len
            // ------------------------------------------------------------------
            rd_req = axi4_rd_seq_item::type_id::create("rd_req");

            if (!rd_req.randomize() with {
                    arburst == 2'b01;
                    arlen   == wr_req.awlen;   // cùng số beat
                    araddr  == wr_req.awaddr;  // cùng địa chỉ
                })
                `uvm_fatal(get_type_name(), "RD Randomization failed")

            rd_seq = axi4_single_rd_seq::type_id::create("rd_seq");
            rd_seq.req = rd_req;
            rd_seq.start(vseqr.rd_seqr);

            // Scoreboard write_rd() sẽ tự in bảng per-beat + verify data
        end

        `uvm_info(get_type_name(), "DONE INCR Burst Read", UVM_LOW)

    endtask

endclass : axi4_incr_burst_rd_seq