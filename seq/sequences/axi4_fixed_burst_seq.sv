`timescale 1ns/1ps

// =============================================================================
// axi4_fixed_burst_seq.sv
// FIXED Burst: tất cả beat ghi/đọc cùng 1 địa chỉ
// AXI4 spec: FIXED burst max 16 beats (awlen <= 15)
// Verify: beat cuối cùng là giá trị còn lại trong SRAM
// =============================================================================

class axi4_fixed_burst_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_fixed_burst_seq)

    int unsigned n_trans = 20;

    function new(string name = "axi4_fixed_burst_seq");
        super.new(name);
    endfunction

    virtual task body();

        axi4_wr_seq_item   wr_req;
        axi4_rd_seq_item   rd_req;
        axi4_single_wr_seq wr_seq;
        axi4_single_rd_seq rd_seq;

        super.body();

        `uvm_info(get_type_name(),
            $sformatf("START FIXED Burst: %0d transactions", n_trans),
            UVM_LOW)

        repeat (n_trans) begin

            // ------------------------------------------------------------------
            // Write: FIXED burst — tất cả beat hit cùng awaddr
            // ------------------------------------------------------------------
            wr_req = axi4_wr_seq_item::type_id::create("wr_req");

            if (!wr_req.randomize() with {
                    awburst == 2'b00;           // FIXED
                    awlen   inside {[1:15]};    // max 16 beats per AXI4 spec
                    awaddr  % 4 == 0;
                    wdata.size() == awlen + 1;
                })
                `uvm_fatal(get_type_name(), "WR Randomization failed")

            `uvm_info(get_type_name(),
                $sformatf("FIXED WR: AWADDR=0x%0h AWLEN=%0d BEATS=%0d (last beat wins)",
                          wr_req.awaddr, wr_req.awlen, wr_req.awlen + 1),
                UVM_MEDIUM)

            wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
            wr_seq.req = wr_req; // đảm bảo seq sẽ lấy constraint theo fixed
            wr_seq.start(vseqr.wr_seqr);

            // ------------------------------------------------------------------
            // Read: cùng địa chỉ, arlen=0 (single beat) —
            // FIXED read 1 beat đủ verify giá trị beat cuối
            // ------------------------------------------------------------------
            //req: single wite sequence 
            rd_req = axi4_rd_seq_item::type_id::create("rd_req");

            if (!rd_req.randomize() with {
                    arburst == 2'b00;           // FIXED
                    arlen   == 0;               // 1 beat — đọc giá trị beat cuối write
                    araddr  == wr_req.awaddr;
                })
                `uvm_fatal(get_type_name(), "RD Randomization failed")

            rd_seq = axi4_single_rd_seq::type_id::create("rd_seq");
            rd_seq.req = rd_req;
            rd_seq.start(vseqr.rd_seqr);

            // Scoreboard sẽ compare rdata[0] với shadow_mem[awaddr>>2]
            // shadow_mem đã được update đúng: beat cuối cùng ghi đè
        end

        `uvm_info(get_type_name(), "DONE FIXED Burst", UVM_LOW)

    endtask

endclass : axi4_fixed_burst_seq