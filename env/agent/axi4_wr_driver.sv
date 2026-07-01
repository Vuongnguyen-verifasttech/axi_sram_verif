`timescale 1ns/1ps

// =============================================================================
// axi4_wr_driver.sv
//
// AXI4 Write Driver (AW + W + B)
//
// Current design goals:
//   - Correct AXI write functionality for current AXI-SRAM DUT
//   - Simple and easy-to-debug implementation
//   - AW and W channels operate concurrently
//   - Transaction completes only after BRESP is received
//
// Reset handling (fixed):
//   run_phase uses fork/join_any to detect reset and kill transaction_loop
//   via disable fork -- deterministic, no race with reset_wr_signals().
//   item_in_flight flag ensures item_done() is always called -- even when
//   transaction_loop is killed mid-transaction -- so the sequencer never
//   gets stuck with an un-acknowledged item ("get_next_item called twice"
//   error). This mirrors the fix already applied in axi4_rd_driver.sv.
//
//   transaction_loop uses try_next_item() (non-blocking) instead of
//   get_next_item() (blocking) to pull items. get_next_item() can suspend
//   for an arbitrary number of cycles waiting on the sequencer -- an event
//   fully independent of reset -- leaving a window where disable fork could
//   kill this process between the sequencer granting the item and
//   item_in_flight being set, still triggering "called twice" on the next
//   grant (observed on Reset 1 in simulation log even with the
//   item_in_flight flag in place). try_next_item() never blocks, closing
//   that window.
//
//   Previous design ran the transaction loop and the reset monitor as two
//   independent forever threads under join_none, with the reset thread only
//   deasserting signals (reset_wr_signals()) while the transaction loop kept
//   running. That created a real NBA race: if reset landed while the
//   transaction loop was between its own internal reset checks, both
//   threads could assign the same interface signal (e.g. wvalid) in the
//   same time step, occasionally leaving AWVALID/WVALID asserted one extra
//   cycle right as reset hit -- root cause of the intermittent
//   "BVALID not LOW after reset" / "B FIFO not empty after reset" failures.
//
// Known limitations / future improvements:
//   1. Direct interface access is used.
//      Future version should migrate to clocking blocks to eliminate
//      potential race conditions.
//
//   2. WVALID is deasserted after every accepted beat.
//      Protocol-legal, but does not model maximum-throughput bursts.
//      Future enhancement may keep WVALID asserted across consecutive beats.
//
//   3. BREADY is permanently asserted (fixed -- see run_phase: bready is
//      now actually driven high after reset release, previously only ever
//      driven low in reset_wr_signals() and never re-asserted).
//      Future tests may add real B-channel backpressure.
//
// Verification status:
//   - AW/W concurrency supported
//   - Backpressure supported on W channel
//   - Clock-aligned handshake sampling
//   - BRESP captured before item_done()
//
// =============================================================================

class axi4_wr_driver extends uvm_driver #(axi4_wr_seq_item);

    // =========================================================================
    // Config & Interface
    // =========================================================================
    axi4_agent_cfg         cfg;
    virtual axi4_if.master vif;

    // Tracks whether get_next_item was called but item_done has not yet been
    // called. Used by the reset handler to call item_done() before restarting.
    bit item_in_flight;

    // =========================================================================
    // UVM
    // =========================================================================
    `uvm_component_utils(axi4_wr_driver)

    function new(string name = "axi4_wr_driver",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =========================================================================
    // Build Phase
    // =========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(axi4_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("WR_DRV_CFG",
                       "Cannot get cfg from config_db")

        if (!uvm_config_db#(virtual axi4_if.master)::get(this, "", "vif", vif))
            `uvm_fatal("WR_DRV_VIF",
                       "Cannot get vif from config_db")
    endfunction

    // =========================================================================
    // Run Phase
    // =========================================================================

    // flow: Get trans tu sequencer --> Gui address (AW) --> Gui data (W) --> Nhan Respone(B) --> Bao hoan thanh --> Next trans
    virtual task run_phase(uvm_phase phase);
        @(posedge vif.i_clk);

        reset_wr_signals();
        wait (vif.i_rst_n === 1'b1);
        @(posedge vif.i_clk);

        // FIX: BREADY was documented as "permanently asserted" but was never
        // actually driven high anywhere in the previous version -- only ever
        // driven low in reset_wr_signals(). Assert it here once reset is
        // released, and again after every subsequent reset (see below).
        vif.master_cb.bready <= 1'b1;

        item_in_flight = 0;

        // ---------------------------------------------------------------
        // Outer loop: (re)fork transaction_loop, kill it deterministically
        // via disable fork the instant reset is detected, then recover.
        // ---------------------------------------------------------------
        forever begin
            fork
                begin : DRV
                    transaction_loop();
                end
                begin : RST_WAIT
                    wait (vif.i_rst_n === 1'b0);
                end
            join_any
            disable fork;   // deterministically kills transaction_loop --
                             // no more racing with reset_wr_signals()

            if (vif.i_rst_n === 1'b0) begin
                `uvm_info(get_type_name(),
                          "Reset detected -- transaction_loop killed",
                          UVM_MEDIUM)

                reset_wr_signals();

                // transaction_loop may have been killed after get_next_item
                // but before item_done(). Call item_done() here so the
                // sequencer does not block the next get_next_item call with
                // the "called twice" error.
                if (item_in_flight) begin
                    seq_item_port.item_done();
                    item_in_flight = 0;
                end

                wait (vif.i_rst_n === 1'b1);
                @(posedge vif.i_clk);

                // FIX: re-assert bready after every reset, not just the
                // very first one.
                vif.master_cb.bready <= 1'b1;

                `uvm_info(get_type_name(),
                          "Reset released -- WR driver ready",
                          UVM_MEDIUM)
            end
        end
    endtask

    // =========================================================================
    // Transaction loop -- called from run_phase fork
    // =========================================================================
    virtual task transaction_loop();
        axi4_wr_seq_item tr;
        forever begin
            // FIX: try_next_item() (non-blocking) instead of get_next_item()
            // (blocking). get_next_item() can suspend for an arbitrary number
            // of cycles waiting for the sequencer to grant an item -- an
            // event fully independent of reset. If disable fork (triggered
            // by RST_WAIT) lands in the gap between the grant becoming
            // visible on the sequencer side and this process reaching
            // "item_in_flight = 1", the sequencer is left with an item it
            // considers outstanding while item_in_flight still reads 0, so
            // the reset-recovery item_done() fallback in run_phase never
            // fires -- causing "get_next_item called twice" on the next
            // grant (observed on Reset 1 in simulation log). try_next_item()
            // never blocks, so there is no multi-cycle window left for that
            // race to land in.
            tr = null;
            while (tr == null) begin
                seq_item_port.try_next_item(tr);
                if (tr == null) @(posedge vif.i_clk);
            end
            item_in_flight = 1;

            `uvm_info(get_type_name(),
                      $sformatf("Driving: %s",
                                tr.convert2string()),
                      UVM_MEDIUM)

            fork
                drive_aw_channel(tr);
                drive_w_channel(tr);
            join

            drive_b_channel(tr);

            item_in_flight = 0;
            seq_item_port.item_done();
        end
    endtask

    // =========================================================================
    // Reset outputs
    // =========================================================================
    virtual task reset_wr_signals();

        // Dùng BLOCKING assign trực tiếp lên net (không qua clocking block)
        // để có hiệu lực NGAY LẬP TỨC — không chờ posedge clock kế tiếp.
        // Tránh data rác (wdata/wvalid cũ) bị DUT sample trong cycle reset đầu tiên.
        vif.awvalid = 1'b0;
        vif.awaddr  = '0;
        vif.awid    = '0;
        vif.awlen   = '0;
        vif.awburst = 2'b01;

        vif.wvalid  = 1'b0;
        vif.wdata   = '0;
        vif.wlast   = 1'b0;

        vif.bready  = 1'b0;

        // Đồng bộ lại giá trị clocking block để tránh glitch khi
        // master_cb output #1 apply đè lên giá trị vừa force ở trên
        vif.master_cb.awvalid <= 1'b0;
        vif.master_cb.awaddr  <= '0;
        vif.master_cb.awid    <= '0;
        vif.master_cb.awlen   <= '0;
        vif.master_cb.awburst <= 2'b01;

        vif.master_cb.wvalid  <= 1'b0;
        vif.master_cb.wdata   <= '0;
        vif.master_cb.wlast   <= 1'b0;

        vif.master_cb.bready  <= 1'b0;

    endtask

    // =========================================================================
    // Drive AW Channel
    // =========================================================================
    virtual task drive_aw_channel(axi4_wr_seq_item tr);
      `uvm_info("DBG_AW", "ENTER drive_aw_channel", UVM_HIGH)

        // Setup phase
        vif.master_cb.awaddr  <= tr.awaddr;
        vif.master_cb.awid    <= tr.awid;
        vif.master_cb.awlen   <= tr.awlen;
        vif.master_cb.awburst <= tr.awburst;
        vif.master_cb.awvalid <= 1'b1;

        // Wait handshake : Moi clk kiem tra awready, neu awready = 0 --> tiep tuc cho, =1 --> handshake thanh cong
          @(posedge vif.i_clk);

            while (!vif.master_cb.awready) begin

                if (!vif.i_rst_n) begin

                    `uvm_warning("AW_RST",
                                "Reset detected while waiting AWREADY")

                    vif.master_cb.awvalid <= 1'b0;
                    vif.master_cb.awaddr  <= '0;

                    return;
                end

                @(posedge vif.i_clk);

            end

                vif.master_cb.awvalid <= 1'b0;
                vif.master_cb.awaddr  <= '0;

        `uvm_info(get_type_name(),
                  $sformatf("AW done: AWADDR=0x%0h AWID=0x%0h AWLEN=%0d",
                            tr.awaddr,
                            tr.awid,
                            tr.awlen),
                  UVM_HIGH)

    endtask

    // =========================================================================
    // Drive W Channel
    // =========================================================================
    virtual task drive_w_channel(axi4_wr_seq_item tr);
        `uvm_info("DRV_W",
            $sformatf("wdata_size=%0d awlen=%0d bp_pct=%0d max_cyc=%0d",
                tr.wdata.size(), tr.awlen,
                cfg.backpressure_pct, cfg.max_backpressure_cycles),
            UVM_HIGH)



        foreach (tr.wdata[i]) begin

            int unsigned bp_cycles;

            // Guard: abandon burst if reset is active at start of any beat
            if (!vif.i_rst_n) begin
                vif.master_cb.wvalid <= 1'b0;
                vif.master_cb.wlast  <= 1'b0;
                return;
            end

                  // Optional backpressure: Kiểm tra DUT có xử lý được data đến không liên tục hay không = cách tự tạo delay
            if (cfg.backpressure_pct > 0) begin

                bp_cycles =
                    ($urandom_range(0,99) < cfg.backpressure_pct) ?
                    $urandom_range(1,cfg.max_backpressure_cycles) :
                    0;

                    if (bp_cycles > 0) begin
                        `uvm_info("WR_BP",
                            $sformatf("W beat[%0d] STALL %0d cycles | bp_pct=%0d%% | AWADDR=0x%0h",
                                i, bp_cycles, cfg.backpressure_pct, tr.awaddr),
                            UVM_HIGH)
                        vif.master_cb.wvalid <= 1'b0;
                        // Use loop so reset is checked on every stall cycle
                        for (int c = 0; c < int'(bp_cycles); c++) begin
                            @(posedge vif.i_clk);
                            if (!vif.i_rst_n) begin
                                vif.master_cb.wvalid <= 1'b0;
                                vif.master_cb.wlast  <= 1'b0;
                                return;
                            end
                        end
                    end
            end

            // Guard: re-check reset after stall before asserting WVALID
            if (!vif.i_rst_n) begin
                vif.master_cb.wvalid <= 1'b0;
                vif.master_cb.wlast  <= 1'b0;
                return;
            end

            // Drive beat
            vif.master_cb.wdata  <= tr.wdata[i];
            vif.master_cb.wlast  <= (i == int'(tr.awlen));
            vif.master_cb.wvalid <= 1'b1;

            // Wait handshake
        @(posedge vif.i_clk);

        // Guard: check reset immediately after clock edge (covers WREADY=1 path)
        if (!vif.i_rst_n) begin
            vif.master_cb.wvalid <= 1'b0;
            vif.master_cb.wlast  <= 1'b0;
            return;
        end

        while (!vif.master_cb.wready) begin

            if (!vif.i_rst_n) begin

                `uvm_warning("W_RST",
                            "Reset detected while waiting WREADY")

                vif.master_cb.wvalid <= 1'b0;
                vif.master_cb.wlast  <= 1'b0;

                return;
            end

            @(posedge vif.i_clk);

        end

        vif.master_cb.wvalid <= 1'b0;

            `uvm_info(get_type_name(),
                      $sformatf("W beat[%0d]: WDATA=0x%0h WLAST=%0b",
                                i,
                                tr.wdata[i],
                                (i == int'(tr.awlen))),
                      UVM_HIGH)

        end

        vif.master_cb.wlast <= 1'b0;

    endtask

    // =========================================================================
    // Drive B Channel
    // =========================================================================
    virtual task drive_b_channel(axi4_wr_seq_item tr);

        @(posedge vif.i_clk);

        while (!vif.master_cb.bvalid) begin

            if (!vif.i_rst_n) begin

                `uvm_warning("B_RST",
                            "Reset detected while waiting BVALID")

                return;

            end

            @(posedge vif.i_clk);

        end
                            `uvm_info("DRV_B",
            $sformatf("@%0t bvalid=%0b bready=%0b bid=%0h",
                $time, vif.master_cb.bvalid,
                vif.master_cb.bready, vif.master_cb.bid),
            UVM_HIGH)
        tr.bresp = vif.master_cb.bresp;
        tr.bid   = vif.master_cb.bid;

        `uvm_info(get_type_name(),
                  $sformatf("B done: BID=0x%0h BRESP=%0b",
                            tr.bid,
                            tr.bresp),
                  UVM_HIGH)

    endtask

endclass : axi4_wr_driver