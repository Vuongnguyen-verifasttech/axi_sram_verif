`timescale 1ns/1ps

// =============================================================================
// axi4_rd_driver.sv
// AXI4 Read Driver: AR channel + R channel (rready management)
//
// Reset handling (redesigned):
//   get_next_item()/item_done() live entirely inside main_drive_loop(), a
//   single process that runs for the whole duration of run_phase and is
//   NEVER disabled/killed from the outside. This is deliberate: the
//   sequencer treats get_next_item()<->item_done() as a contract owned by
//   exactly one process. Any external "disable fork" that can land between
//   the sequencer granting an item and this process acknowledging it
//   corrupts the sequencer's internal arbitration state permanently (seen
//   as recurring "get_next_item/try_next_item called twice" errors in sim,
//   regardless of whether get_next_item() or try_next_item() is used --
//   changing the API does not fix an ownership problem).
//
//   Reset-driven abort of an in-flight transaction is handled the way it
//   always should have been: via the existing "if (!vif.i_rst_n) return;"
//   checks inside drive_ar_channel()/drive_r_channel(). Those checks run
//   inside the SAME process that holds the item, so whichever path is
//   taken, control always flows back to exactly one item_done() call --
//   no external kill, no flag bookkeeping, no race.
//
//   A separate reset_monitor() thread only ever touches physical interface
//   signals (never seq_item_port). It re-asserts idle values every clock
//   cycle for as long as reset stays low (not just once on the negedge), so
//   any transient signal race with main_drive_loop's own checkpoints
//   self-corrects within one cycle instead of persisting.
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
        // Blocking assign directly on the net -- takes effect immediately,
        // without waiting for the next posedge (avoids garbage data being
        // sampled by the DUT in the very first reset cycle).
        vif.arvalid = 1'b0;
        vif.rready  = 1'b0;
        vif.araddr  = '0;

        // Also drive the clocking block outputs so they don't overwrite the
        // value just forced above on the next clock edge.
        vif.master_cb.arvalid <= 1'b0;
        vif.master_cb.rready  <= 1'b0;
        vif.master_cb.araddr  <= '0;
    endtask

    // =========================================================================
    // Run Phase
    // =========================================================================
    virtual task run_phase(uvm_phase phase);
        fork
            reset_monitor();
            main_drive_loop();
        join_none
    endtask

    // =========================================================================
    // Reset monitor -- ONLY touches physical interface signals. Never calls
    // anything on seq_item_port. Runs for the entire simulation, independent
    // of and never interfering with main_drive_loop's ownership of the
    // sequencer item-pull contract.
    // =========================================================================
    virtual task reset_monitor();
        forever begin
            wait (vif.i_rst_n === 1'b0);
            `uvm_info(get_type_name(), "Reset detected -- forcing RD signals idle", UVM_MEDIUM)

            // Keep re-asserting idle every cycle for as long as reset stays
            // low. This bounds any transient race with main_drive_loop's own
            // reset checkpoints to at most one cycle instead of letting it
            // persist.
            while (vif.i_rst_n === 1'b0) begin
                reset_rd_signals();
                @(posedge vif.i_clk);
            end

            `uvm_info(get_type_name(), "Reset released -- RD driver ready", UVM_MEDIUM)
        end
    endtask

    // =========================================================================
    // Main drive loop -- the ONLY place that touches seq_item_port. Runs for
    // the entire duration of run_phase; never forked/killed/re-forked.
    // get_next_item() is allowed to block indefinitely: that is completely
    // safe, since there is nothing to clean up while no item has been
    // granted yet. Once an item IS granted, drive_ar_channel/drive_r_channel
    // handle reset internally and always return control here, guaranteeing
    // item_done() is called exactly once per get_next_item().
    // =========================================================================
    virtual task main_drive_loop();
        axi4_rd_seq_item tr;
        bit              ar_accepted;
        forever begin
            seq_item_port.get_next_item(tr);

            // KHONG bat dau transaction moi khi reset con active: neu drive
            // ngay bay gio ta se assert ARVALID trong luc i_rst_n=0, vi pham
            // AXI reset spec (master phai giu VALID LOW khi reset). Cho reset
            // nha ra roi moi drive. Block o day an toan: item da duoc grant,
            // item_done() chi don gian bi hoan lai.
            while (vif.i_rst_n === 1'b0)
                @(posedge vif.i_clk);

            drive_ar_channel(tr, ar_accepted);

            // Chi cho R response khi AR that su duoc DUT nhan. Neu reset abort
            // truoc AR handshake, khong co read nao ton tai -> khong drive_r
            // (tranh cho rvalid cua read khong ton tai / dem sai beat).
            if (ar_accepted)
                drive_r_channel(tr);

            seq_item_port.item_done();
        end
    endtask

    // =========================================================================
    // Drive AR Channel
    // =========================================================================
    // accepted = 1 chi khi AR handshake (ARVALID && ARREADY) that su hoan tat.
    // Neu reset abort truoc handshake, accepted=0 -> caller phai BO drive_r,
    // vi khong co read nao duoc DUT nhan -> khong duoc di cho R data cua mot
    // read khong ton tai.
    virtual task drive_ar_channel(axi4_rd_seq_item tr, output bit accepted);
        `uvm_info("DBG_AR", $sformatf("ENTER drive_ar_channel ARADDR=0x%0h", tr.araddr), UVM_HIGH)

        accepted = 1'b0;

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
        accepted = 1'b1;   // handshake AR thanh cong -> se co R response
    endtask

    // =========================================================================
    // Drive R Channel
    //
    // Beat chi duoc dem khi co HANDSHAKE THAT: rvalid && rready cung cao tai
    // dung edge DUT pop R FIFO (giong cach monitor sample). Truoc day driver
    // dem beat chi theo rvalid va deassert rready TRUOC moi beat; ket hop voi
    // output skew (#1) cua clocking block, viec bat/tat rready lien tuc lam
    // so beat driver dem LECH so voi transfer thuc -> bo lo beat co rlast ->
    // bao RLAST_MISSING oan (du DUT dua rlast dung). Fix: assert rready mot
    // lan va GIU, backpressure deassert SAU beat (khong mat beat o bien stall).
    //
    // Exit conditions:
    //   Normal : rlast asserted by DUT
    //   Error  : beat_cnt reaches expected_beats without rlast (RLAST_MISSING)
    //   Reset  : detected internally, returns cleanly back to main_drive_loop
    // =========================================================================
    virtual task drive_r_channel(axi4_rd_seq_item tr);

        int unsigned expected_beats;
        int unsigned beat_cnt;
        int unsigned bp_cycles;

        expected_beats = tr.arlen + 1;
        beat_cnt       = 0;
        tr.rdata.delete();

        // Assert rready mot lan, giu cao xuyen suot (tru khi co backpressure).
        vif.master_cb.rready <= 1'b1;

        forever begin

            @(posedge vif.i_clk);

            if (!vif.i_rst_n) begin
                vif.master_cb.rready <= 1'b0;
                return;
            end

            // Chi dem khi co transfer that: rvalid && rready cung cao.
            if (!(vif.master_cb.rvalid && vif.master_cb.rready))
                continue;

            // ------------------------------------------------------------------
            // Handshake -- capture beat
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

            // ------------------------------------------------------------------
            // Backpressure: deassert rready SAU beat vua nhan, stall N cycle,
            // roi re-assert. Deassert co hieu luc o edge ke -> khong pop mat
            // beat -> khong lech dem.
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
                    vif.master_cb.rready <= 1'b1;
                end
            end

        end // forever

        vif.master_cb.rready <= 1'b0;

        `uvm_info(get_type_name(),
                  $sformatf("R done: RID=0x%0h BEATS=%0d/%0d RRESP=%0b",
                             tr.rid, beat_cnt, expected_beats, tr.rresp),
                  UVM_MEDIUM)

    endtask

endclass : axi4_rd_driver