`timescale 1ns/1ps

// =============================================================================
// axi4_driver.sv
// Driver cho AXI4 Master Agent - Drive transaction vào DUT (slave)
// =============================================================================

class axi4_driver extends uvm_driver #(axi4_transaction);

    // =====================================================================
    // Configuration & Interface
    // =====================================================================
    axi4_agent_cfg   cfg;
    virtual axi4_if.master vif;        // Modport master

    // =====================================================================
    // UVM Automation
    // =====================================================================
    `uvm_component_utils(axi4_driver)

    // Constructor
    function new(string name = "axi4_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =====================================================================
    // Build Phase - Lấy cfg và interface
    // =====================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("DRV_CFG", "Cannot get agent cfg from config_db")

        if (!uvm_config_db#(virtual axi4_if.master)::get(this, "", "vif", vif))
            `uvm_fatal("DRV_VIF", "Cannot get virtual interface from config_db")
    endfunction

    // =====================================================================
    // Run Phase - Main loop
    // =====================================================================
    virtual task run_phase(uvm_phase phase);
        // Reset interface lúc đầu
        reset_signals();

        forever begin
            seq_item_port.get_next_item(req);   // Lấy transaction từ sequencer

            `uvm_info(get_type_name(), $sformatf("Driving transaction: %s", req.convert2string()), UVM_MEDIUM)

            if (req.is_write)
                drive_write_transaction(req);
            else
                drive_read_transaction(req);

            seq_item_port.item_done();          // Báo transaction đã drive xong
        end
    endtask

    // =====================================================================
    // Reset all master signals
    // =====================================================================
    virtual task reset_signals();
        vif.awvalid <= 0;
        vif.wvalid  <= 0;
        vif.bready  <= 1;     // Master luôn ready với response
        vif.arvalid <= 0;
        vif.rready  <= 1;     // Master luôn ready với read data
    endtask

    // =====================================================================
    // Drive Write Transaction (AW + W + B)
    // =====================================================================
    virtual task drive_write_transaction(axi4_transaction tr);
        // --- Drive AW channel ---
        vif.awaddr  <= tr.awaddr;
        vif.awid    <= tr.id;
        vif.awlen   <= tr.len;
        vif.awburst <= tr.burst;
        vif.awvalid <= 1;

        wait (vif.awready);
        @(posedge vif.i_clk);
        vif.awvalid <= 0;

        // --- Drive W channel (từng beat) ---
        foreach (tr.data[i]) begin
            vif.wdata  <= tr.data[i];
            vif.wlast  <= (i == tr.len);
            vif.wvalid <= 1;

            // Random backpressure trên WREADY
            if ($urandom_range(0, 99) < cfg.backpressure_pct)
                vif.wvalid <= 0;   // Thêm 1 cycle delay

            wait (vif.wready);
            @(posedge vif.i_clk);
            vif.wvalid <= 0;
        end

        // --- Wait B response ---
        vif.bready <= 1;
        wait (vif.bvalid);
        tr.resp = vif.bresp;          // Capture response cho scoreboard
        @(posedge vif.i_clk);
    endtask

    // =====================================================================
    // Drive Read Transaction (AR + R)
    // =====================================================================
    virtual task drive_read_transaction(axi4_transaction tr);
        // --- Drive AR channel ---
        vif.araddr  <= tr.araddr;
        vif.arid    <= tr.id;
        vif.arlen   <= tr.len;
        vif.arburst <= tr.burst;
        vif.arvalid <= 1;

        wait (vif.arready);
        @(posedge vif.i_clk);
        vif.arvalid <= 0;

        // --- Receive R channel (từng beat) ---
        tr.data.delete();   // Clear queue trước khi nhận data
        repeat (tr.len + 1) begin
            vif.rready <= 1;

            wait (vif.rvalid);
            tr.data.push_back(vif.rdata);
            tr.resp = vif.rresp;      // Capture response

            if (vif.rlast)
                break;

            @(posedge vif.i_clk);
        end
        vif.rready <= 0;
    endtask

endclass : axi4_driver