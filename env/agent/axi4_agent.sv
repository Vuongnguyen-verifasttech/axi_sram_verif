`timescale 1ns/1ps

// =============================================================================
// axi4_agent.sv
// AXI4 Master Agent — tích hợp per-channel drivers và monitors
//
// Cấu trúc (active mode):
//   wr_driver   : axi4_wr_driver  — drive AW+W+B
//   rd_driver   : axi4_rd_driver  — drive AR+R
//   wr_monitor  : axi4_wr_monitor — observe AW+W+B
//   rd_monitor  : axi4_rd_monitor — observe AR+R
//
// Sequencer:
//   wr_seqr : uvm_sequencer #(axi4_wr_seq_item)
//   rd_seqr : uvm_sequencer #(axi4_rd_seq_item)
//
// Analysis ports (forwarded từ monitor ra env):
//   ap_wr   → scoreboard write port
//   ap_rd   → scoreboard read port
// =============================================================================

class axi4_agent extends uvm_agent;

    // =========================================================================
    // Sub-components
    // =========================================================================
    axi4_wr_driver  wr_driver;
    axi4_rd_driver  rd_driver;
    axi4_wr_monitor wr_monitor;
    axi4_rd_monitor rd_monitor;

    uvm_sequencer #(axi4_wr_seq_item) wr_seqr;
    uvm_sequencer #(axi4_rd_seq_item) rd_seqr;

    // =========================================================================
    // Configuration
    // =========================================================================
    axi4_agent_cfg cfg;

    // =========================================================================
    // Analysis ports — forward từ monitor ra ngoài
    // =========================================================================
    uvm_analysis_port #(axi4_wr_seq_item) ap_wr;
    uvm_analysis_port #(axi4_rd_seq_item) ap_rd;

    // =========================================================================
    // UVM
    // =========================================================================
    `uvm_component_utils(axi4_agent)

    function new(string name = "axi4_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =========================================================================
    // Build Phase
    // =========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Lấy config — tạo default nếu không có
        if (!uvm_config_db#(axi4_agent_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_info(get_type_name(), "cfg not found, creating default", UVM_LOW)
            cfg = axi4_agent_cfg::type_id::create("cfg");
        end

        // Forward cfg xuống cho các subcomponent
        uvm_config_db#(axi4_agent_cfg)::set(this, "wr_driver",  "cfg", cfg);
        uvm_config_db#(axi4_agent_cfg)::set(this, "rd_driver",  "cfg", cfg);
        uvm_config_db#(axi4_agent_cfg)::set(this, "wr_monitor", "cfg", cfg);
        uvm_config_db#(axi4_agent_cfg)::set(this, "rd_monitor", "cfg", cfg);

        // Tạo monitor (luôn active, bất kể agent mode)
        wr_monitor = axi4_wr_monitor::type_id::create("wr_monitor", this);
        rd_monitor = axi4_rd_monitor::type_id::create("rd_monitor", this);

        // Tạo analysis port forward
        ap_wr = new("ap_wr", this);
        ap_rd = new("ap_rd", this);

        // Tạo driver + sequencer chỉ khi active
        if (cfg.is_active == UVM_ACTIVE) begin
            wr_seqr  = uvm_sequencer#(axi4_wr_seq_item)::type_id::create("wr_seqr", this);
            rd_seqr  = uvm_sequencer#(axi4_rd_seq_item)::type_id::create("rd_seqr", this);
            wr_driver = axi4_wr_driver::type_id::create("wr_driver", this);
            rd_driver = axi4_rd_driver::type_id::create("rd_driver", this);
        end
    endfunction

    // =========================================================================
    // Connect Phase
    // =========================================================================
    virtual function void connect_phase(uvm_phase phase);
        // Driver ↔ Sequencer
        if (cfg.is_active == UVM_ACTIVE) begin
            wr_driver.seq_item_port.connect(wr_seqr.seq_item_export);
            rd_driver.seq_item_port.connect(rd_seqr.seq_item_export);
        end

        // Monitor analysis ports → agent's forwarding ports
        wr_monitor.ap_wr.connect(ap_wr);
        rd_monitor.ap_rd.connect(ap_rd);
    endfunction

endclass : axi4_agent