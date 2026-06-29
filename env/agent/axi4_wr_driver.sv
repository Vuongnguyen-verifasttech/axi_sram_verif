`timescale 1ns/1ps

// =============================================================================
// axi4_wr_driver.sv
// AXI4 Write Driver (AW + W + B)
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

    function new(string name = "axi4_wr_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =========================================================================
    // Build Phase
    // =========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
                      
        if (!uvm_config_db#(axi4_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("WR_DRV_CFG", "Cannot get cfg from config_db")

        if (!uvm_config_db#(virtual axi4_if.master)::get(this, "", "vif", vif))
            `uvm_fatal("WR_DRV_VIF", "Cannot get vif from config_db")
    endfunction

    // Reset tín hiệu về default - Độc lập hoàn toàn
    virtual task reset_wr_signals();
        vif.master_cb.awvalid <= 1'b0;
        vif.master_cb.wvalid  <= 1'b0;
        vif.master_cb.wlast   <= 1'b0;
        vif.master_cb.bready  <= 1'b1;
        vif.master_cb.awaddr  <= '0;
        vif.master_cb.awid    <= '0;
        vif.master_cb.awlen   <= '0;
        vif.master_cb.awburst <= 2'b01;
    endtask

    // =========================================================================
    // Run Phase (Đã được cấu trúc lại cho Reset)
    // =========================================================================
    vvirtual task run_phase(uvm_phase phase);
        fork
            watchdog_reset();
            main_drive_loop();
        join
    endtask

    // Luồng giám sát Reset (Watchdog)
    virtual task watchdog_reset();
        forever begin
            wait(vif.i_rst_n === 1'b0);
            disable main_drive_loop; // Ép dừng luồng chính tức thì
            reset_wr_signals();
            wait(vif.i_rst_n === 1'b1);
            @(posedge vif.i_clk);
        end
    endtask

    // Luồng chính (Chỉ chứa logic AXI4 thuần túy)
    virtual task main_drive_loop();
        axi4_wr_seq_item tr;
        forever begin
            seq_item_port.get_next_item(tr);
            fork
                drive_aw_channel(tr);
                drive_w_channel(tr);
            join
            drive_b_channel(tr);
            seq_item_port.item_done();
        end
    endtask


    // =========================================================================
    // Drive AW Channel (Logic gốc)
    // =========================================================================
    virtual task drive_aw_channel(axi4_wr_seq_item tr);
        `uvm_info("DBG_AW","ENTER drive_aw_channel", UVM_NONE)

        vif.master_cb.awaddr  <= tr.awaddr;
        vif.master_cb.awid    <= tr.awid;
        vif.master_cb.awlen   <= tr.awlen;
        vif.master_cb.awburst <= tr.awburst;
        vif.master_cb.awvalid <= 1'b1;
        @(posedge vif.i_clk);
        while (!vif.master_cb.awready) @(posedge vif.i_clk);
        vif.master_cb.awvalid <= 1'b0;

        `uvm_info(get_type_name(),
                  $sformatf("AW done: AWADDR=0x%0h AWID=0x%0h AWLEN=%0d", tr.awaddr, tr.awid, tr.awlen),
                  UVM_HIGH)
    endtask

    // =========================================================================
    // Drive W Channel (Logic gốc)
    // =========================================================================
    virtual task drive_w_channel(axi4_wr_seq_item tr);
        `uvm_info("DRV_W", $sformatf("wdata_size=%0d awlen=%0d", tr.wdata.size(), tr.awlen), UVM_NONE)
        `uvm_info("DRV_HANDLE", $sformatf("cfg=%p bp=%0d max_cyc=%0d", cfg, cfg.backpressure_pct, cfg.max_backpressure_cycles), UVM_NONE)

        foreach (tr.wdata[i]) begin
            int unsigned bp_cycles;
            if (cfg.backpressure_pct > 0) begin
                bp_cycles = ($urandom_range(0,99) < cfg.backpressure_pct) ? $urandom_range(1,cfg.max_backpressure_cycles) : 0;
                
                `uvm_info("WR_BP_DBG", $sformatf("bp_pct=%0d max_cyc=%0d bp_cycles=%0d beat=%0d", cfg.backpressure_pct, cfg.max_backpressure_cycles, bp_cycles, i), UVM_NONE)

                if (bp_cycles > 0) begin
                    `uvm_info("WR_BP", $sformatf("W beat[%0d] STALL %0d cycles | bp_pct=%0d%% | AWADDR=0x%0h", i, bp_cycles, cfg.backpressure_pct, tr.awaddr), UVM_LOW)
                    vif.master_cb.wvalid <= 1'b0;
                    repeat (bp_cycles) @(posedge vif.i_clk);
                end
            end

            // Drive beat
            vif.master_cb.wdata  <= tr.wdata[i];
            vif.master_cb.wlast  <= (i == int'(tr.awlen));
            vif.master_cb.wvalid <= 1'b1;
            @(posedge vif.i_clk);
            while (!vif.master_cb.wready) @(posedge vif.i_clk);
            vif.master_cb.wvalid <= 1'b0;
        end
        vif.master_cb.wlast <= 1'b0;
    endtask

    // =========================================================================
    // Drive B Channel (Logic gốc)
    // =========================================================================
   virtual task drive_b_channel(axi4_wr_seq_item tr);
        @(posedge vif.i_clk);
        while (!vif.master_cb.bvalid) @(posedge vif.i_clk);
        tr.bresp = vif.master_cb.bresp;
        tr.bid   = vif.master_cb.bid;
    endtask

endclass : axi4_wr_driver