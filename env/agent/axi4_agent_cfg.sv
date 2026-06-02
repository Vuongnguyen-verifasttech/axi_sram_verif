`timescale 1ns/1ps

// =============================================================================
// axi4_agent_cfg.sv
// Configuration class cho AXI4 Master Agent
// =============================================================================

class axi4_agent_cfg extends uvm_object;

    // =====================================================================
    // Basic agent configuration
    // =====================================================================
    rand bit is_active;          // 1 = Active (driver + sequencer), 0 = Passive (monitor only)

    // =====================================================================
    // Coverage & Checking control
    // =====================================================================
    rand bit enable_coverage;    // Bật/tắt functional + protocol coverage
    rand bit enable_scoreboard;  // Bật/tắt scoreboard checking

    // =====================================================================
    // Backpressure & Protocol behavior
    // =====================================================================
    rand int unsigned backpressure_pct;   // % xác suất READY low (0-100)
    rand int unsigned max_outstanding;    // Số transaction tối đa outstanding

    // =====================================================================
    // Constraints
    // =====================================================================
    constraint c_default_cfg {
        is_active         == 1;                    // Mặc định là Active agent
        enable_coverage   == 1;
        enable_scoreboard == 1;
        backpressure_pct  inside {[0:40]};         // 0-40% backpressure (dễ debug ban đầu)
        max_outstanding   inside {[1:8]};          // Phù hợp với FIFO depth=8 của DUT
    }

    // =====================================================================
    // UVM Automation
    // =====================================================================
    `uvm_object_utils_begin(axi4_agent_cfg)
        `uvm_field_int(is_active,         UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(enable_coverage,   UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(enable_scoreboard, UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(backpressure_pct,  UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(max_outstanding,   UVM_ALL_ON | UVM_DEC)
    `uvm_object_utils_end

    // Constructor
    function new(string name = "axi4_agent_cfg");
        super.new(name);
        // Default values (có thể override trong test)
        is_active         = 1;
        enable_coverage   = 1;
        enable_scoreboard = 1;
        backpressure_pct  = 20;
        max_outstanding   = 8;
    endfunction

    // Print config (dễ debug)
    virtual function string convert2string();
        string s;
        s = $sformatf("is_active=%0b | coverage=%0b | scoreboard=%0b | backpressure=%0d%% | max_outstanding=%0d",
                      is_active, enable_coverage, enable_scoreboard, 
                      backpressure_pct, max_outstanding);
        return s;
    endfunction

endclass : axi4_agent_cfg