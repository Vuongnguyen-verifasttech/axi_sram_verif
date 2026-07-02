`timescale 1ns/1ps

// =============================================================================
// axi4_incr_burst_wr_seq.sv
// AXI_05 - INCR Burst Write
//
// Mục tiêu:
//   - Drive INCR burst write full range: awlen = 1..255 (2..256 beats)
//   - Check: BRESP=OKAY, BID==AWID sau mỗi transaction
//   - Số transaction random: mặc định 20
// =============================================================================

class axi4_incr_burst_wr_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_incr_burst_wr_seq)

    int unsigned n_trans = 20;

    function new(string name = "axi4_incr_burst_wr_seq");
        super.new(name);
    endfunction

    virtual task body();

        axi4_wr_seq_item   req;
        axi4_single_wr_seq wr_seq;

        super.body();

        `uvm_info(get_type_name(),
            $sformatf("START INCR Burst Write: %0d transactions", n_trans),
            UVM_LOW)

        repeat (n_trans) begin

            req = axi4_wr_seq_item::type_id::create("req");

            // Item mac dinh cap awlen [0:15] (c_len_range, cho sim nhanh). Test
            // nay chu dich phu FULL INCR range 2..256 beats nen tat cap do.
            // (awaddr align + wdata.size == awlen+1 van do item rang buoc san.)
            req.c_len_range.constraint_mode(0);

            if (!req.randomize() with {
                    awburst == 2'b01;                        // INCR
                    awlen   inside {[1:255]};                 // 2..256 beats
                    // Giu TOAN BO burst trong SRAM 4KB. Item chi rang buoc dia
                    // chi BAT DAU (c_addr_range [0:0xFFF]); voi burst dai, dia
                    // chi cuoi (awaddr + (awlen+1)*4) co the vuot range -> ghi
                    // ngoai vung / alias. Rang buoc end-addr o day chan viec do.
                    awaddr + (awlen + 1) * 4 <= 32'h0000_1000;
                })
                `uvm_fatal(get_type_name(), "Randomization failed")

            `uvm_info(get_type_name(),
                $sformatf("Sending: AWID=0x%0h AWADDR=0x%0h AWLEN=%0d BEATS=%0d",
                          req.awid, req.awaddr, req.awlen, req.awlen + 1),
                UVM_MEDIUM)

            wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
            wr_seq.req = req;
            wr_seq.start(vseqr.wr_seqr);

            // Check BRESP
            if (req.bresp !== 2'b00)
                `uvm_error(get_type_name(),
                    $sformatf("FAIL: BRESP=0x%0h (expected OKAY) AWID=0x%0h AWADDR=0x%0h",
                              req.bresp, req.awid, req.awaddr))
            else
                `uvm_info(get_type_name(),
                    $sformatf("PASS: BRESP=OKAY AWID=0x%0h AWADDR=0x%0h AWLEN=%0d",
                              req.awid, req.awaddr, req.awlen),
                    UVM_MEDIUM)

            // Check BID == AWID
            if (req.bid !== req.awid)
                `uvm_error(get_type_name(),
                    $sformatf("FAIL: BID=0x%0h != AWID=0x%0h", req.bid, req.awid))

        end

        `uvm_info(get_type_name(), "DONE INCR Burst Write", UVM_LOW)

    endtask

endclass : axi4_incr_burst_wr_seq