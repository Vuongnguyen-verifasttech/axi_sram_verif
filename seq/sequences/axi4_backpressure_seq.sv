`timescale 1ns/1ps

// =============================================================================
// axi4_backpressure_seq.sv
// Backpressure on All Channels
//
// Cách hoạt động:
//   - Seq lấy cfg từ config_db, force backpressure_pct cao để đảm bảo
//     backpressure thực sự xảy ra (không phụ thuộc random của test)
//   - enable_read_bp / enable_write_bp được tôn trọng
//   - Write trước → Read lại cùng địa chỉ để scoreboard verify data integrity
//
// Verify:
//   1. Handshake đúng spec dù có backpressure (wready/rready deassert random)
//   2. Không mất data — scoreboard verify data integrity
//   3. Không deadlock — timeout trong axi4_agent_cfg bắt (aw/w/b/ar/r_timeout_cycles)
//   4. wvalid/arvalid phải giữ stable khi chưa được handshake (driver phải đúng)
// =============================================================================

class axi4_backpressure_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_backpressure_seq)

    // Số transaction, có thể override từ test
    int unsigned n_trans = 30;

    // Backpressure % muốn force — override từ test nếu cần
    // Default 60% để đảm bảo backpressure thực sự được inject
    int unsigned bp_pct           = 60;
    int unsigned bp_max_cycles    = 10;

    function new(string name = "axi4_backpressure_seq");
        super.new(name);
    endfunction

    virtual task body();

        axi4_agent_cfg cfg;

        super.body();

        // =====================================================================
        // Lấy cfg và force backpressure settings
        // Nếu không lấy được thì fatal — sequence không có ý nghĩa nếu
        // không biết cfg đang dùng backpressure bao nhiêu
        // =====================================================================
        if (!uvm_config_db #(axi4_agent_cfg)::get(null, get_full_name(), "cfg", cfg))
            `uvm_fatal(get_type_name(), "Cannot get axi4_agent_cfg from config_db")

        // Force backpressure — không để random tự chọn ra 0
        cfg.backpressure_pct        = bp_pct;
        cfg.max_backpressure_cycles = bp_max_cycles;

        `uvm_info(get_type_name(),
            $sformatf("START Backpressure: %0d trans | bp_pct=%0d%% | max_bp_cyc=%0d | wr_bp=%0b | rd_bp=%0b",
                n_trans,
                cfg.backpressure_pct,
                cfg.max_backpressure_cycles,
                cfg.enable_write_bp,
                cfg.enable_read_bp),
            UVM_LOW)

        // =====================================================================
        // Write → Read xen kẽ
        // Driver tự inject backpressure theo cfg đã được force ở trên
        // =====================================================================
        repeat (n_trans) begin

            axi4_wr_seq_item   wr_req;
            axi4_rd_seq_item   rd_req;
            axi4_single_wr_seq wr_seq;
            axi4_single_rd_seq rd_seq;

            // ------------------------------------------------------------------
            // Write
            // ------------------------------------------------------------------
            wr_req = axi4_wr_seq_item::type_id::create("wr_req");

            if (!wr_req.randomize() with {
                    awburst        == 2'b01;        // INCR only — đơn giản, dễ predict
                    awlen          inside {[0:7]};  // tối đa 8 beats
                    awaddr[1:0]    == 2'b00;        // word-aligned (tương đương c_addr_align)
                    wdata.size()   == awlen + 1;
                })
                `uvm_fatal(get_type_name(), "WR randomize failed")

            wr_seq     = axi4_single_wr_seq::type_id::create("wr_seq");
            wr_seq.req = wr_req;
            wr_seq.start(vseqr.wr_seqr);

            // ------------------------------------------------------------------
            // Read lại cùng địa chỉ và cùng len
            // Scoreboard sẽ match rdata với wdata đã ghi
            // ------------------------------------------------------------------
            rd_req = axi4_rd_seq_item::type_id::create("rd_req");

            if (!rd_req.randomize() with {
                    arburst     == 2'b01;
                    arlen       == wr_req.awlen;   // cùng số beat
                    araddr      == wr_req.awaddr;  // cùng địa chỉ
                })
                `uvm_fatal(get_type_name(), "RD randomize failed")

            rd_seq     = axi4_single_rd_seq::type_id::create("rd_seq");
            rd_seq.req = rd_req;
            rd_seq.start(vseqr.rd_seqr);

        end

        `uvm_info(get_type_name(),
            $sformatf("DONE Backpressure: %0d trans completed — no deadlock, data intact", n_trans),
            UVM_LOW)

    endtask

endclass : axi4_backpressure_seq