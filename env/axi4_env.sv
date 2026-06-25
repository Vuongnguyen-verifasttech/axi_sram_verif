`timescale 1ns/1ps

// =============================================================================
// axi4_env.sv
// Main UVM Environment - Đã tích hợp scoreboard
// =============================================================================

class axi4_env extends uvm_env;

    // =====================================================================
    // Configuration
    // =====================================================================
    axi4_env_cfg   env_cfg;

    // =====================================================================
    // Components
    // =====================================================================
    axi4_agent           axi_agent;
    axi4_scoreboard      scoreboard;
    virtual axi4_if vif;     
    axi4_virtual_seqr    virtual_seqr;

    // =====================================================================
    // UVM Automation
    // =====================================================================
    `uvm_component_utils(axi4_env)

    // Constructor
    function new(string name = "axi4_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =====================================================================
    // Build Phase
    // =====================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Lấy env config
        if (!uvm_config_db#(axi4_env_cfg)::get(this, "", "env_cfg", env_cfg))
            `uvm_fatal("ENV_CFG", "Cannot get env_cfg from config_db")

        // Pass agent_cfg xuống agent
        `uvm_info("FORCE_BP",
    $sformatf("BEFORE SET bp=%0d",
        env_cfg.agent_cfg.backpressure_pct),
    UVM_NONE)

env_cfg.agent_cfg.backpressure_pct = 55;
env_cfg.agent_cfg.max_backpressure_cycles = 9;

uvm_config_db#(axi4_agent_cfg)::set(
    this,
    "axi_agent*",
    "cfg",
    env_cfg.agent_cfg
);

        // Tạo các component
        axi_agent      = axi4_agent::type_id::create("axi_agent", this);
        scoreboard     = axi4_scoreboard::type_id::create("scoreboard", this);
        virtual_seqr   = axi4_virtual_seqr::type_id::create("virtual_seqr", this);

        `uvm_info(get_type_name(), $sformatf("Environment built successfully!\n%s", env_cfg.convert2string()), UVM_LOW)
    endfunction

    // =====================================================================
    // Connect Phase - Kết nối TLM
    // =====================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Kết nối monitor analysis ports → scoreboard
        axi_agent.ap_wr.connect(scoreboard.ae_wr);
        axi_agent.ap_rd.connect(scoreboard.ae_rd);

        // Kết nối virtual sequencer → agent sequencers
        virtual_seqr.wr_seqr = axi_agent.wr_seqr;
        virtual_seqr.rd_seqr = axi_agent.rd_seqr;
        virtual_seqr.vif = vif; 

        `uvm_info(get_type_name(), "Environment connections completed (wr/rd scoreboard ports + virtual sequencer connected)", UVM_LOW)
    endfunction

    // =====================================================================
    // Report Phase
    // =====================================================================
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "AXI4 SRAM UVM Environment finished successfully", UVM_LOW)
    endfunction

endclass : axi4_env