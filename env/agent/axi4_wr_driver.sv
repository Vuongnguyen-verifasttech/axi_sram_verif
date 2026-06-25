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
// Known limitations / future improvements:
//   1. No reset recovery during active transaction.
//      Current implementation assumes reset only occurs before test starts.
//
//   2. Direct interface access is used.
//      Future version should migrate to clocking blocks to eliminate
//      potential race conditions.
//
//   3. WVALID is deasserted after every accepted beat.
//      Protocol-legal, but does not model maximum-throughput bursts.
//      Future enhancement may keep WVALID asserted across consecutive beats.
//
//   4. BREADY is permanently asserted.
//      Sufficient for current DUT verification.
//      Future tests may add B-channel backpressure.
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

    // flow: Get trans tu sequencer --> Gui address (AW) --> Gui data (W) --> Nhan Respone(B) --> Bao hoan thanh --> Next trans
    virtual task run_phase(uvm_phase phase);
        @(posedge vif.i_clk);

        reset_wr_signals();

       wait (vif.i_rst_n === 1'b1);
    @(posedge vif.i_clk);  // Wait for DUT & if stable 

        forever begin

            axi4_wr_seq_item tr;

            seq_item_port.get_next_item(tr);

            `uvm_info(get_type_name(),
                      $sformatf("Driving: %s",
                                tr.convert2string()),
                      UVM_MEDIUM)

            // AW và W chạy song song , do axi cho phep AW, va W hoat dong // nen al dung fork join 
            fork
                drive_aw_channel(tr);
                drive_w_channel(tr);
            join

            // Chờ BRESP
            drive_b_channel(tr);

            seq_item_port.item_done();

        end

    endtask

    // =========================================================================
    // Reset outputs
    // =========================================================================
    virtual task reset_wr_signals();

        vif.master_cb.awvalid <= 1'b0;
        vif.master_cb.awaddr  <= '0;
        vif.master_cb.awid    <= '0;
        vif.master_cb.awlen   <= '0;
        vif.master_cb.awburst <= 2'b01;

        vif.master_cb.wvalid  <= 1'b0;
        vif.master_cb.wdata   <= '0;
        vif.master_cb.wlast   <= 1'b0;

        vif.master_cb.bready  <= 1'b1;

    endtask

    // =========================================================================
    // Drive AW Channel
    // =========================================================================
    virtual task drive_aw_channel(axi4_wr_seq_item tr);
      `uvm_info("DBG_AW","ENTER drive_aw_channel", UVM_NONE)   // <-- thêm dòng này

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

        foreach (tr.wdata[i]) begin

            int unsigned bp_cycles;

                  // Optional backpressure: Kiểm tra DUT có xử lý được data đến không liên tục hay không = cách tự tạo delay 
            if (cfg.backpressure_pct > 0) begin

                bp_cycles =
                    ($urandom_range(0,99) < cfg.backpressure_pct) ?
                    $urandom_range(1,cfg.max_backpressure_cycles) :
                    0;

 // THÊM 2 DÒNG NÀY
                    `uvm_info("WR_BP_DBG",
                        $sformatf("bp_pct=%0d max_cyc=%0d bp_cycles=%0d beat=%0d",
                            cfg.backpressure_pct, cfg.max_backpressure_cycles,
                            bp_cycles, i),
                        UVM_NONE)

                    if (bp_cycles > 0) begin
                        `uvm_info("WR_BP",
                            $sformatf("W beat[%0d] STALL %0d cycles | bp_pct=%0d%% | AWADDR=0x%0h",
                                i, bp_cycles, cfg.backpressure_pct, tr.awaddr),
                            UVM_LOW)
                        vif.master_cb.wvalid <= 1'b0;
                        repeat (bp_cycles) @(posedge vif.i_clk);
                    end
            end

            // Drive beat
            vif.master_cb.wdata  <= tr.wdata[i];
            vif.master_cb.wlast  <= (i == int'(tr.awlen));
            vif.master_cb.wvalid <= 1'b1;

            // Wait handshake
        @(posedge vif.i_clk);

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
            $sformatf(
            "@%0t bvalid=%0b bready=%0b bid=%0h",
            $time,
            vif.master_cb.bvalid,
            vif.master_cb.bready,
            vif.master_cb.bid),
            UVM_NONE)
        tr.bresp = vif.master_cb.bresp;
        tr.bid   = vif.master_cb.bid;

        `uvm_info(get_type_name(),
                  $sformatf("B done: BID=0x%0h BRESP=%0b",
                            tr.bid,
                            tr.bresp),
                  UVM_HIGH)

    endtask

endclass : axi4_wr_driver