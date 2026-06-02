`timescale 1ns/1ps

// =============================================================================
// axi4_monitor.sv
// Monitor quan sát và capture transaction từ DUT (AXI4 Slave)
// =============================================================================

class axi4_monitor extends uvm_monitor;

    // =====================================================================
    // Configuration & Interface
    // =====================================================================
    axi4_agent_cfg               cfg;
    virtual axi4_if.slave        vif;          // Modport slave (DUT view)

    // Analysis port để gửi transaction ra scoreboard & coverage
    uvm_analysis_port #(axi4_transaction) ap;

    // =====================================================================
    // UVM Automation
    // =====================================================================
    `uvm_component_utils(axi4_monitor)

    // Constructor
    function new(string name = "axi4_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =====================================================================
    // Build Phase
    // =====================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(axi4_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("MON_CFG", "Cannot get agent cfg")

        if (!uvm_config_db#(virtual axi4_if.slave)::get(this, "", "vif", vif))
            `uvm_fatal("MON_VIF", "Cannot get virtual interface")

        ap = new("ap", this);
    endfunction

    // =====================================================================
    // Run Phase - Main monitoring loop
    // =====================================================================
    virtual task run_phase(uvm_phase phase);
        forever begin
            fork
                monitor_write_channel();
                monitor_read_channel();
            join
        end
    endtask

    // =====================================================================
    // Monitor Write Transaction (AW + W + B)
    // =====================================================================
    virtual task monitor_write_channel();
        axi4_transaction tr;

        forever begin
            // Chờ AW handshake
            wait (vif.awvalid && vif.awready);
            tr = axi4_transaction::type_id::create("tr_write");
            tr.is_write = 1;
            tr.awaddr   = vif.awaddr;
            tr.id       = vif.awid;
            tr.len      = vif.awlen;
            tr.burst    = vif.awburst;

            @(posedge vif.i_clk);

            // Thu thập toàn bộ W data
            tr.data.delete();
            do begin
                wait (vif.wvalid && vif.wready);
                tr.data.push_back(vif.wdata);
                if (vif.wlast) break;
                @(posedge vif.i_clk);
            end while (1);

            // Chờ B response
            wait (vif.bvalid && vif.bready);
            tr.resp = vif.bresp;

            `uvm_info(get_type_name(), $sformatf("Captured WRITE: %s", tr.convert2string()), UVM_MEDIUM)
            ap.write(tr);          // Gửi cho scoreboard
            @(posedge vif.i_clk);
        end
    endtask

    // =====================================================================
    // Monitor Read Transaction (AR + R)
    // =====================================================================
    virtual task monitor_read_channel();
        axi4_transaction tr;

        forever begin
            // Chờ AR handshake
            wait (vif.arvalid && vif.arready);
            tr = axi4_transaction::type_id::create("tr_read");
            tr.is_write = 0;
            tr.araddr   = vif.araddr;
            tr.id       = vif.arid;
            tr.len      = vif.arlen;
            tr.burst    = vif.arburst;

            @(posedge vif.i_clk);

            // Thu thập toàn bộ R data
            tr.data.delete();
            do begin
                wait (vif.rvalid && vif.rready);
                tr.data.push_back(vif.rdata);
                tr.resp = vif.rresp;
                if (vif.rlast) break;
                @(posedge vif.i_clk);
            end while (1);

            `uvm_info(get_type_name(), $sformatf("Captured READ: %s", tr.convert2string()), UVM_MEDIUM)
            ap.write(tr);          // Gửi cho scoreboard
            @(posedge vif.i_clk);
        end
    endtask

endclass : axi4_monitor