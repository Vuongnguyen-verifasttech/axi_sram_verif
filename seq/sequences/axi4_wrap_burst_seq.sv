`timescale 1ns/1ps

// =============================================================================
// axi4_wrap_burst_seq.sv
// WRAP Burst — mục tiêu expose RTL bug trong DUT
//
// AXI4 spec WRAP:
//   - awlen+1 phải thuộc {2, 4, 8, 16} beats
//   - awaddr phải align theo (beats * 4) bytes
//   - wrap_boundary = (awaddr / (beats*4)) * (beats*4)
//   - Khi addr+4 vượt wrap_boundary + beats*4 → wrap về wrap_boundary
//
// DUT bug:
//   addr_wrap = (addr + 4) & ~3  → chỉ align 4 bytes, không wrap → hành vi như INCR
//   → Scoreboard (tính đúng spec) sẽ expected khác DUT → SB_RD FAIL → bug exposed
// =============================================================================

class axi4_wrap_burst_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_wrap_burst_seq)

    int unsigned n_trans = 20;

    // beats hợp lệ với WRAP theo AXI4 spec: {2,4,8,16} → awlen = {1,3,7,15}
    int unsigned valid_awlen[$] = '{1, 3, 7, 15};

    function new(string name = "axi4_wrap_burst_seq");
        super.new(name);
    endfunction

    virtual task body();

        axi4_wr_seq_item   wr_req;
        axi4_rd_seq_item   rd_req;
        axi4_single_wr_seq wr_seq;
        axi4_single_rd_seq rd_seq;

        super.body();

        `uvm_info(get_type_name(),
            $sformatf("START WRAP Burst: %0d transactions (targeting RTL bug)", n_trans),
            UVM_LOW)

        repeat (n_trans) begin

            int unsigned beats;
            logic [31:0] wrap_boundary;
            int unsigned awlen_val;

            // ------------------------------------------------------------------
            // Pick random valid awlen từ {1,3,7,15}
            // ------------------------------------------------------------------
            awlen_val = valid_awlen[$urandom_range(0, 3)];
            beats     = awlen_val + 1;

            // ------------------------------------------------------------------
            // Write WRAP burst
            // awaddr phải align theo beats*4 để wrap boundary rõ ràng
            // ------------------------------------------------------------------
            wr_req = axi4_wr_seq_item::type_id::create("wr_req");

            // Item mac dinh chi cho INCR (c_burst_type: awburst inside {2'b01}).
            // Test nay can WRAP (2'b10) nen phai TAT c_burst_type, neu khong
            // inline awburst==2'b10 mau thuan voi item -> randomize FAIL -> fatal.
            wr_req.c_burst_type.constraint_mode(0);

            if (!wr_req.randomize() with {
                    awburst == 2'b10;                       // WRAP
                    awlen   == awlen_val;
                    // awaddr align 4 byte (transfer size) da co san o item
                    // (c_addr_align). O DAY ep awaddr KHONG nam o wrap_boundary
                    // (tuc awaddr % (beats*4) != 0) de burst BAT DAU giua vung
                    // -> chac chan co WRAP giua burst -> lo duoc bug DUT (DUT
                    // khong wrap). Neu awaddr == boundary thi 16 beat lap dung
                    // vung, KHONG wrap -> khong lo bug (day la loi fix truoc).
                    awaddr % (beats * 4) != 0;
                    wdata.size() == awlen + 1;
                })
                `uvm_fatal(get_type_name(), "WR Randomization failed")

            wrap_boundary = (wr_req.awaddr / (beats * 4)) * (beats * 4);

            `uvm_info(get_type_name(),
                $sformatf("WRAP WR: AWADDR=0x%0h AWLEN=%0d BEATS=%0d wrap_boundary=0x%0h wrap_top=0x%0h",
                          wr_req.awaddr, wr_req.awlen, beats,
                          wrap_boundary, wrap_boundary + beats*4),
                UVM_MEDIUM)

            wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
            wr_seq.req = wr_req;
            wr_seq.start(vseqr.wr_seqr);

            // ------------------------------------------------------------------
            // Read lại cùng địa chỉ, cùng len
            // Scoreboard tính expected theo WRAP spec → compare với DUT
            // ------------------------------------------------------------------
            rd_req = axi4_rd_seq_item::type_id::create("rd_req");

            // Tuong tu: tat c_burst_type de cho phep WRAP (2'b10) o read.
            rd_req.c_burst_type.constraint_mode(0);

            if (!rd_req.randomize() with {
                    arburst == 2'b10;
                    arlen   == wr_req.awlen;
                    araddr  == wr_req.awaddr;
                })
                `uvm_fatal(get_type_name(), "RD Randomization failed")

            rd_seq = axi4_single_rd_seq::type_id::create("rd_seq");
            rd_seq.req = rd_req;
            rd_seq.start(vseqr.rd_seqr);

            // Scoreboard write_rd() sẽ tính expected theo WRAP spec chuẩn
            // DUT trả về theo logic sai → mismatch → SB_RD FAIL → bug exposed

        end

        `uvm_info(get_type_name(),
            "======================DONE WRAP Burst =============================",
            UVM_LOW)

    endtask

endclass : axi4_wrap_burst_seq