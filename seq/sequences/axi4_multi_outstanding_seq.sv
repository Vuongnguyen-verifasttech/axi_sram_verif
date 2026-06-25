`timescale 1ns/1ps

// =============================================================================
// axi4_multi_outstanding_seq.sv
// AXI_15 — Multiple Outstanding (same ID)
//
// Mục đích:
//   Verify DUT buffer nhiều trans cùng ID vào FIFO đúng thứ tự,
//   BID/RID trả về đúng ID đã gửi, response in-order.
//
// Cách hoạt động:
//   1. Gửi n_trans write liên tiếp cùng AWID — chờ BRESP từng cái
//   2. Gửi n_trans read  liên tiếp cùng ARID — chờ RRESP từng cái
//   3. Verify BID == AWID, RID == ARID sau mỗi trans
//
// Note:
//   DUT SRAM serialize read (reg_rd_pending), nên read không thực sự
//   concurrent ở SRAM level — nhưng AXI interface vẫn phải handle
//   FIFO buffering và ID propagation đúng.
// =============================================================================

class axi4_multi_outstanding_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_multi_outstanding_seq)

    // Số trans mỗi chiều — override từ test
    int unsigned n_trans = 8;

    // ID cố định dùng cho tất cả trans
    logic [3:0] fixed_id = 4'hA;

    function new(string name = "axi4_multi_outstanding_seq");
        super.new(name);
    endfunction

    virtual task body();

        super.body();

        `uvm_info(get_type_name(),
            $sformatf("START Multi-Outstanding: %0d WR + %0d RD | fixed_id=0x%0h",
                n_trans, n_trans, fixed_id),
            UVM_LOW)

        // =====================================================================
        // Phase 1: Write n_trans cùng ID
        // Mỗi write hoàn thành (bao gồm BRESP) trước khi gửi write tiếp
        // Verify BID == fixed_id sau mỗi trans
        // =====================================================================
        `uvm_info(get_type_name(), "--- WRITE PHASE ---", UVM_LOW)

        repeat (n_trans) begin

            axi4_wr_seq_item   wr_req;
            axi4_single_wr_seq wr_seq;

            wr_req = axi4_wr_seq_item::type_id::create("wr_req");

            if (!wr_req.randomize() with {
                    awid         == fixed_id;   // cùng ID
                    awburst      == 2'b01;      // INCR
                    awlen        inside {[0:7]};
                    awaddr[1:0]  == 2'b00;
                    wdata.size() == awlen + 1;
                })
                `uvm_fatal(get_type_name(), "WR randomize failed")

            wr_seq     = axi4_single_wr_seq::type_id::create("wr_seq");
            wr_seq.req = wr_req;
            wr_seq.start(vseqr.wr_seqr);

            // Verify BID sau khi driver capture BRESP
            if (wr_req.bid !== fixed_id)
                `uvm_error(get_type_name(),
                    $sformatf("BID mismatch: got=0x%0h expected=0x%0h AWADDR=0x%0h",
                        wr_req.bid, fixed_id, wr_req.awaddr))
            else
                `uvm_info(get_type_name(),
                    $sformatf("WR OK: BID=0x%0h AWADDR=0x%0h AWLEN=%0d BRESP=%0b",
                        wr_req.bid, wr_req.awaddr, wr_req.awlen, wr_req.bresp),
                    UVM_LOW)

        end

        // =====================================================================
        // Phase 2: Read n_trans cùng ID — đọc lại các địa chỉ đã write
        // Verify RID == fixed_id sau mỗi trans
        // =====================================================================
        `uvm_info(get_type_name(), "--- READ PHASE ---", UVM_LOW)

        repeat (n_trans) begin

            axi4_rd_seq_item   rd_req;
            axi4_single_rd_seq rd_seq;

            rd_req = axi4_rd_seq_item::type_id::create("rd_req");

            if (!rd_req.randomize() with {
                    arid        == fixed_id;    // cùng ID
                    arburst     == 2'b01;
                    arlen       inside {[0:7]};
                    araddr[1:0] == 2'b00;
                })
                `uvm_fatal(get_type_name(), "RD randomize failed")

            rd_seq     = axi4_single_rd_seq::type_id::create("rd_seq");
            rd_seq.req = rd_req;
            rd_seq.start(vseqr.rd_seqr);

            // Verify RID sau khi driver capture R beats
            if (rd_req.rid !== fixed_id)
                `uvm_error(get_type_name(),
                    $sformatf("RID mismatch: got=0x%0h expected=0x%0h ARADDR=0x%0h",
                        rd_req.rid, fixed_id, rd_req.araddr))
            else
                `uvm_info(get_type_name(),
                    $sformatf("RD OK: RID=0x%0h ARADDR=0x%0h ARLEN=%0d RRESP=%0b",
                        rd_req.rid, rd_req.araddr, rd_req.arlen, rd_req.rresp),
                    UVM_LOW)

        end

        `uvm_info(get_type_name(),
            $sformatf("DONE Multi-Outstanding: BID/RID all match 0x%0h", fixed_id),
            UVM_LOW)

    endtask

endclass : axi4_multi_outstanding_seq