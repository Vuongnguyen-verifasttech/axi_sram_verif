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

        reset_wr_signals();

        @(posedge vif.i_clk); // Wait for DUT & if stable 

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

        vif.awvalid <= 1'b0;
        vif.awaddr  <= '0;
        vif.awid    <= '0;
        vif.awlen   <= '0;
        vif.awburst <= 2'b01;

        vif.wvalid  <= 1'b0;
        vif.wdata   <= '0;
        vif.wlast   <= 1'b0;

        vif.bready  <= 1'b1;

    endtask

    // =========================================================================
    // Drive AW Channel
    // =========================================================================
    virtual task drive_aw_channel(axi4_wr_seq_item tr);

        // Setup phase
        vif.awaddr  <= tr.awaddr;
        vif.awid    <= tr.awid;
        vif.awlen   <= tr.awlen;
        vif.awburst <= tr.awburst;
        vif.awvalid <= 1'b1;

        // Wait handshake : Moi clk kiem tra awready, neu awready = 0 --> tiep tuc cho, =1 --> handshake thanh cong
        do begin
            @(posedge vif.i_clk);
        end
        while (!vif.awready);

        // Handshake completed : address trans da ket thuc --> DUT da nhan du thong tin AW 
        vif.awvalid <= 1'b0;
        vif.awaddr  <= '0;

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

                if (bp_cycles > 0) begin
                    vif.wvalid <= 1'b0;
                    repeat (bp_cycles)
                        @(posedge vif.i_clk);
                end
            end

            // Drive beat
            vif.wdata  <= tr.wdata[i];
            vif.wlast  <= (i == int'(tr.awlen));
            vif.wvalid <= 1'b1;

            // Wait handshake
            do begin
                @(posedge vif.i_clk);
            end
            while (!vif.wready);

            // Beat accepted
            vif.wvalid <= 1'b0;

            `uvm_info(get_type_name(),
                      $sformatf("W beat[%0d]: WDATA=0x%0h WLAST=%0b",
                                i,
                                tr.wdata[i],
                                (i == int'(tr.awlen))),
                      UVM_HIGH)

        end

        vif.wlast <= 1'b0;

    endtask

    // =========================================================================
    // Drive B Channel
    // =========================================================================
    virtual task drive_b_channel(axi4_wr_seq_item tr);

        do begin
            @(posedge vif.i_clk);
        end
        while (!vif.bvalid);

        tr.bresp = vif.bresp;
        tr.bid   = vif.bid;

        `uvm_info(get_type_name(),
                  $sformatf("B done: BID=0x%0h BRESP=%0b",
                            tr.bid,
                            tr.bresp),
                  UVM_HIGH)

    endtask

endclass : axi4_wr_driver