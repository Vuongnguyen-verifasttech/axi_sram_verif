`timescale 1ns/1ps

// =============================================================================
// axi4_env_cfg.sv
// Configuration cho toàn bộ AXI4 SRAM UVM Environment
// =============================================================================

class axi4_env_cfg extends uvm_object;

    // =====================================================================
    // Agent configuration (composition)
    // =====================================================================
    axi4_agent_cfg  agent_cfg;

    // =====================================================================
    // Environment level controls
    // =====================================================================
    rand bit        enable_scoreboard;
    rand bit        enable_coverage;
    rand int unsigned max_sim_time;      // Giới hạn thời gian mô phỏng (nếu cần)

    // DUT specific
    rand int unsigned fifo_depth;        // Phù hợp với PARA_FIFO_DEPTH của DUT

    // =====================================================================
    // Constraints
    // =====================================================================
    constraint c_default_env_cfg {
        enable_scoreboard == 1;
        enable_coverage   == 1;
        fifo_depth        == 8;                    // Khớp với DUT hiện tại
        max_sim_time      inside {[1000:10000]};  // 1k ~ 10k ns
    }

    // =====================================================================
    // UVM Automation
    // =====================================================================
    `uvm_object_utils_begin(axi4_env_cfg)
        `uvm_field_object(agent_cfg, UVM_ALL_ON)
        `uvm_field_int(enable_scoreboard, UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(enable_coverage,   UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(fifo_depth,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(max_sim_time,      UVM_ALL_ON | UVM_DEC)
    `uvm_object_utils_end

    // Constructor
    function new(string name = "axi4_env_cfg");
        super.new(name);
        
        // Tạo agent_cfg
        agent_cfg = axi4_agent_cfg::type_id::create("agent_cfg");
        
        // Default values
        enable_scoreboard = 1;
        enable_coverage   = 1;
        fifo_depth        = 8;
        max_sim_time      = 5000;
    endfunction

    // Print config (rất hữu ích khi debug)
    virtual function string convert2string();
        string s;
        s = $sformatf("ENV_CFG: scoreboard=%0b | coverage=%0b | fifo_depth=%0d | agent_cfg={%s}",
                      enable_scoreboard, enable_coverage, fifo_depth, 
                      agent_cfg.convert2string());
        return s;
    endfunction

endclass : axi4_env_cfg