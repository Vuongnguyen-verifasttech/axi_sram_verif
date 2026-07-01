`timescale 1ns/1ps

// =============================================================================
// axi4_rd_driver.sv
// AXI4 Read Driver: AR channel + R channel (rready management)
//
// Reset handling:
//   run_phase uses fork/join_any to detect reset and kill main_drive_loop.
//   item_in_flight flag ensures item_done() is always called — even when
//   main_drive_loop is killed mid-transaction — so the sequencer never gets
//   stuck with an un-acknowledged item ("get_next_item called twice" error).
//
//   main_drive_loop uses try_next_item() (non-blocking) instead of
//   get_next_item() (blocking) to pull items. get_next_item() can suspend
//   for an arbitrary number of cycles waiting on the sequencer -- an event
//   fully independent of reset -- leaving a window where disable fork could
//   kill this process between the sequencer granting the item and
//   item_in_flight being set, still triggering "called twice" on the next
//   grant. try_next_item() never blocks, closing that window.
//
// drive_r_channel exit conditions:
//   Primary  : rlast asserted by DUT (correct AXI behavior)
//   Fallback : beat_cnt == expected_beats with no rlast (RTL bug, logged)
// =============================================================================

class axi4_rd_driver extends uvm_driver #(axi4_rd_seq_item);

    // =========================================================================
    // Config & Interface
    // =========================================================================
    axi4_agent_cfg          cfg;
    virtual axi4_if.master  vif;

    // Tracks whether get_next_item was called but item_done has not yet been
    // called. Used by the reset handler to call item_done() before restarting.
    bit item_in_flight;

    // =========================================================================
    // UVM
    // =========================================================================
    `uvm_component_utils(axi4_rd_driver)

    function new(string name = "axi4_rd_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =========================================================================
    // Build Phase
    // =========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("RD_DRV_CFG", "Cannot get cfg from config_db")
        if (!uvm_config_db#(virtual axi4_if.master)::get(this, "", "vif", vif))
            `uvm_fatal("RD_DRV_VIF", "Cannot get vif from config_db")
    endfunction

    // =========================================================================
    // Reset outputs
    // =========================================================================
    virtual task reset_rd_signals();
        vif.arvalid = 1'b0;
        vif.rready  = 1'b0;
        vif.araddr  = '0;

        vif.master_cb.arvalid <= 1'b0;
        vif.master_cb.rready  <= 1'b0;
        vif.master_cb.araddr  <= '0;
    endtask

    // =========================================================================
    // Run Phase
    // =========================================================================
    virtual task run_phase(uvm_phase phase);
        item_in_flight = 0;

        forever begin
            fork
                begin : DRV
                    main_drive_loop();
                end
                begin : RST_WAIT
                    wait(vif.i_rst_n === 1'b0);
                end
            join_any
            disable fork;

            if (vif.i_rst_n === 1'b0) begin
                `uvm_info(get_type_name(), "Reset detected -- main_drive_loop killed", UVM_MEDIUM)
                reset_rd_signals();

                // main_drive_loop may have been killed after get_next_item but
                // before item_done. Call item_done here so the sequencer does
                // not block the next get_next_item call with the "called twice"
                // error.
                if (item_in_flight) begin
                    seq_item_port.item_done();
                    item_in_flight = 0;
                end

                wait(vif.i_rst_n === 1'b1);
                @(posedge vif.i_clk);
                `uvm_info(get_type_name(), "Reset released -- RD driver ready", UVM_MEDIUM)
            end
        end
    endtask

    // =========================================================================
    // Main drive loop — called from run_phase fork
    // =========================================================================
    virtual task main_drive_loop();
        axi4_rd_seq_item tr;
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
            // grant. try_next_item() never blocks, so there is no multi-
            // cycle window left for that race to land in.
            tr = null;
            while (tr == null) begin
                seq_item_port.try_next_item(tr);
                if (tr == null) @(posedge vif.i_clk);
            end
            item_in_flight = 1;

            drive_ar_channel(tr);
            drive_r_channel(tr);

            item_in_flight = 0;
            seq_item_port.item_done();
        end
    endtask

    // =========================================================================
    // Drive AR Channel
    // =========================================================================
    virtual task drive_ar_channel(axi4_rd_seq_item tr);
        `uvm_info("DBG_AR", $sformatf("ENTER drive_ar_channel ARADDR=0x%0h", tr.araddr), UVM_HIGH)

        vif.master_cb.araddr  <= tr.araddr;
        vif.master_cb.arid    <= tr.arid;
        vif.master_cb.arlen   <= tr.arlen;
        vif.master_cb.arburst <= tr.arburst;
        vif.master_cb.arvalid <= 1'b1;

        @(posedge vif.i_clk);

        if (!vif.i_rst_n) begin
            vif.master_cb.arvalid <= 1'b0;
            return;
        end

        while (!vif.master_cb.arready) begin
            if (!vif.i_rst_n) begin
                vif.master_cb.arvalid <= 1'b0;
                return;
            end
            @(posedge vif.i_clk);
        end

        vif.master_cb.arvalid <= 1'b0;
    endtask

    // =========================================================================
    // Drive R Channel
    //
    // Exit conditions:
    //   Normal : rlast asserted by DUT
    //   RTL bug: beat_cnt reaches expected_beats without rlast (RLAST_MISSING)
    //   Reset  : main_drive_loop killed by disable fork in run_phase
    // =========================================================================
    virtual task drive_r_channel(axi4_rd_seq_item tr);

        int unsigned expected_beats;
        int unsigned beat_cnt;

        expected_beats = tr.arlen + 1;
        beat_cnt       = 0;
        tr.rdata.delete();

        forever begin

            int unsigned bp_cycles;

            // ------------------------------------------------------------------
            // Backpressure: deassert rready before accepting beat
            // ------------------------------------------------------------------
            if (cfg.backpressure_pct > 0) begin
                bp_cycles = ($urandom_range(0, 99) < cfg.backpressure_pct) ?
                            $urandom_range(1, cfg.max_backpressure_cycles) : 0;
                if (bp_cycles > 0) begin
                    `uvm_info("RD_BP",
                        $sformatf("R beat[%0d] STALL %0d cycles | bp_pct=%0d%% | ARADDR=0x%0h",
                            beat_cnt, bp_cycles, cfg.backpressure_pct, tr.araddr),
                        UVM_HIGH)
                    vif.master_cb.rready <= 1'b0;
                    for (int c = 0; c < int'(bp_cycles); c++) begin
                        @(posedge vif.i_clk);
                        if (!vif.i_rst_n) begin
                            vif.master_cb.rready <= 1'b0;
                            return;
                        end
                    end
                end
            end

            // ------------------------------------------------------------------
            // Assert rready, wait for rvalid
            // ------------------------------------------------------------------
            vif.master_cb.rready <= 1'b1;

            do begin
                @(posedge vif.i_clk);
                if (!vif.i_rst_n) begin
                    vif.master_cb.rready <= 1'b0;
                    return;
                end
            end while (!vif.master_cb.rvalid);

            // ------------------------------------------------------------------
            // Handshake — capture beat
            // ------------------------------------------------------------------
            tr.rdata.push_back(vif.master_cb.rdata);
            tr.rresp = vif.master_cb.rresp;
            tr.rid   = vif.master_cb.rid;
            beat_cnt++;

            `uvm_info(get_type_name(),
                      $sformatf("R beat[%0d]: RDATA=0x%0h RLAST=%0b RRESP=%0b",
                                 beat_cnt-1, vif.master_cb.rdata,
                                 vif.master_cb.rlast, vif.master_cb.rresp),
                      UVM_HIGH)

            // ------------------------------------------------------------------
            // Check rlast
            // ------------------------------------------------------------------
            if (vif.master_cb.rlast) begin
                if (beat_cnt != expected_beats)
                    `uvm_error(get_type_name(),
                        $sformatf("** RTL BUG ** RLAST_EARLY: rlast at beat[%0d] but expected=%0d beats | ARADDR=0x%0h ARLEN=%0d",
                            beat_cnt-1, expected_beats, tr.araddr, tr.arlen))
                break;
            end

            if (beat_cnt == expected_beats) begin
                `uvm_error(get_type_name(),
                    $sformatf("** RTL BUG ** RLAST_MISSING: received %0d beats but rlast not asserted | ARADDR=0x%0h ARLEN=%0d",
                        expected_beats, tr.araddr, tr.arlen))
                break;
            end

        end // forever

        vif.master_cb.rready <= 1'b0;

        `uvm_info(get_type_name(),
                  $sformatf("R done: RID=0x%0h BEATS=%0d/%0d RRESP=%0b",
                             tr.rid, beat_cnt, expected_beats, tr.rresp),
                  UVM_MEDIUM)

    endtask

endclass : axi4_rd_driver