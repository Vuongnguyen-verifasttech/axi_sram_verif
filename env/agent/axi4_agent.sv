`timescale 1ns/1ps

// =============================================================================
// axi4_agent.sv
// Top-level AXI4 Master Agent - Tổng hợp driver, monitor, sequencer
// =============================================================================

class axi4_agent extends uvm_agent;

    // =====================================================================
    // Component instances
    // =====================================================================
    axi4_agent_cfg    cfg;
    axi4_driver       driver;
    axi4_monitor      monitor;
    axi4_sequencer    sequencer;

    // Analysis port (export từ monitor) để kết nối ra scoreboard/coverage
    uvm_analysis_port #(axi4_transaction) ap;

    // =====================================================================
    // UVM Automation
    // =====================================================================
    `uvm_component_utils(axi4_agent)

    // Constructor
    function new(string name = "axi4_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =====================================================================
    // Build Phase - Tạo instance các component con
    // =====================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Lấy config từ config_db
        if (!uvm_config_db#(axi4_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("AGT_CFG", "Cannot get agent cfg from config_db")

        // Luôn tạo monitor (dù active hay passive)
        monitor = axi4_monitor::type_id::create("monitor", this);

        // Nếu là Active agent → tạo driver + sequencer
        if (cfg.is_active) begin
            driver    = axi4_driver::type_id::create("driver", this);
            sequencer = axi4_sequencer::type_id::create("sequencer", this);
        end

        ap = new("ap", this);
    endfunction

    // =====================================================================
    // Connect Phase - Kết nối TLM ports
    // =====================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect monitor analysis port ra ngoài
        monitor.ap.connect(ap);

        // Nếu active thì connect sequencer ↔ driver
        if (cfg.is_active) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

    // =====================================================================
    // Helper function (dễ debug)
    // =====================================================================
    virtual function string convert2string();
        return $sformatf("AXI4 Agent: is_active=%0b | cfg=%s", cfg.is_active, cfg.convert2string());
    endfunction

endclass : axi4_agent