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
// Reset handling (redesigned):
//   get_next_item()/item_done() live entirely inside transaction_loop(), a
//   single process that runs for the whole duration of run_phase and is
//   NEVER disabled/killed from the outside. The sequencer treats
//   get_next_item()<->item_done() as a contract owned by exactly one
//   process; any external "disable fork" that can land between the
//   sequencer granting an item and this process acknowledging it corrupts
//   the sequencer's internal arbitration state permanently -- seen as
//   recurring "get_next_item/try_next_item called twice" errors. Swapping
//   get_next_item() for try_next_item() does not fix this: it is an
//   ownership problem, not an API/blocking-vs-non-blocking problem.
//
//   Reset-driven abort of an in-flight transaction is handled the way it
//   always should have been: via the existing "if (!vif.i_rst_n) return;"
//   checks inside drive_aw_channel()/drive_w_channel()/drive_b_channel().
//   Those checks run inside the SAME process that holds the item, so
//   whichever path is taken, control always flows back to exactly one
//   item_done() call -- no external kill, no flag bookkeeping, no race.
//
//   A separate reset_monitor() thread only ever touches physical interface
//   signals (never seq_item_port). It re-asserts idle values every clock
//   cycle for as long as reset stays low (not just once on the negedge), so
//   any transient signal race with transaction_loop's own checkpoints
//   self-corrects within one cycle instead of persisting -- this is what
//   fixed the original intermittent "BVALID not LOW after reset" /
//   "B FIFO not empty after reset" failures.
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
//   3. BREADY is permanently asserted -- actually driven high in
//      reset_monitor() right after reset release (previously documented
//      but never implemented: bready was only ever driven low).
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
    virtual task run_phase(uvm_phase phase);
        fork
            reset_monitor();
            transaction_loop();
        join_none
    endtask

    // =========================================================================
    // Reset monitor -- ONLY touches physical interface signals. Never calls
    // anything on seq_item_port. Runs for the entire simulation, independent
    // of and never interfering with transaction_loop's ownership of the
    // sequencer item-pull contract.
    // =========================================================================
    virtual task reset_monitor();
        forever begin
            wait (vif.i_rst_n === 1'b0);
            `uvm_info(get_type_name(), "Reset detected -- forcing WR signals idle", UVM_MEDIUM)

            // Keep re-asserting idle every cycle for as long as reset stays
            // low. This bounds any transient race with transaction_loop's own
            // reset checkpoints to at most one cycle instead of letting it
            // persist -- this is what fixes the intermittent spurious
            // BVALID / B FIFO not-empty failures.
            while (vif.i_rst_n === 1'b0) begin
                reset_wr_signals();
                @(posedge vif.i_clk);
            end

            @(posedge vif.i_clk);
            vif.master_cb.bready <= 1'b1;   // BREADY is permanently asserted
                                             // once reset is released
            `uvm_info(get_type_name(), "Reset released -- WR driver ready", UVM_MEDIUM)
        end
    endtask

    // =========================================================================
    // Transaction loop -- the ONLY place that touches seq_item_port. Runs
    // for the entire duration of run_phase; never forked/killed/re-forked.
    // get_next_item() is allowed to block indefinitely: that is completely
    // safe, since there is nothing to clean up while no item has been
    // granted yet. Once an item IS granted, drive_aw_channel/drive_w_channel/
    // drive_b_channel handle reset internally and always return control
    // here, guaranteeing item_done() is called exactly once per
    // get_next_item().
    // =========================================================================
    virtual task transaction_loop();
        axi4_wr_seq_item tr;
        forever begin
            seq_item_port.get_next_item(tr);

            // KHONG bat dau transaction moi khi reset con active: neu drive
            // ngay bay gio ta se assert AWVALID/WVALID trong luc i_rst_n=0, vi
            // pham AXI reset spec (master phai giu VALID LOW khi reset). Cho
            // reset nha ra roi moi drive. Block o day an toan: item da duoc
            // grant, item_done() chi don gian bi hoan lai.
            while (vif.i_rst_n === 1'b0)
                @(posedge vif.i_clk);

            `uvm_info(get_type_name(),
                      $sformatf("Driving: %s",
                                tr.convert2string()),
                      UVM_MEDIUM)

            fork
                drive_aw_channel(tr);
                drive_w_channel(tr);
            join

            drive_b_channel(tr);

            seq_item_port.item_done();
        end
    endtask

    // =========================================================================
    // Reset outputs
    // =========================================================================
    virtual task reset_wr_signals();

        // Blocking assign directly on the net (not through the clocking
        // block) -- takes effect IMMEDIATELY, without waiting for the next
        // posedge. Avoids stale wdata/wvalid being sampled by the DUT in the
        // very first reset cycle.
        vif.awvalid = 1'b0;
        vif.awaddr  = '0;
        vif.awid    = '0;
        vif.awlen   = '0;
        vif.awburst = 2'b01;

        vif.wvalid  = 1'b0;
        vif.wdata   = '0;
        vif.wlast   = 1'b0;

        vif.bready  = 1'b0;

        // Also re-sync the clocking block outputs so they don't get
        // overwritten by whatever was pending from before the force above.
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

            // Guard: check reset immediately after clock edge. Neu reset assert
            // dung o edge nay va AWREADY tinh co =1 (spec cho phep READY bat ky
            // gia tri khi reset), khong co guard nay driver se tuong nham la
            // handshake AW thanh cong. Bat reset o day de return sach, dong bo
            // voi drive_w_channel()/drive_ar_channel().
            if (!vif.i_rst_n) begin

                `uvm_warning("AW_RST",
                            "Reset detected while waiting AWREADY")

                vif.master_cb.awvalid <= 1'b0;
                vif.master_cb.awaddr  <= '0;

                return;
            end

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