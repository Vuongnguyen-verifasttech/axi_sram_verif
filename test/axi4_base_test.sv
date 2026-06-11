`timescale 1ns/1ps

// =============================================================================
// axi4_base_test.sv
// Base test - Test cơ bản nhất của UVM environment
// =============================================================================

import axi4_env_pkg::*;

class axi4_base_test extends uvm_test;

    // =====================================================================
    // Environment
    // =====================================================================
    axi4_env env;
    axi4_env_cfg   env_cfg;

    // =====================================================================
    // UVM Automation
    // =====================================================================
    `uvm_component_utils(axi4_base_test)

    // Constructor
    function new(string name = "axi4_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =====================================================================
    // Build Phase
    // =====================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 1. Tạo config object
        env_cfg = axi4_env_cfg::type_id::create("env_cfg");

        // 2. SET vào config_db - PHẢI làm trước khi env build_phase chạy
        uvm_config_db#(axi4_env_cfg)::set(this, "env", "env_cfg", env_cfg);

        // 3. Tạo env
        env = axi4_env::type_id::create("env", this);
    endfunction

    // =====================================================================
    // Run Phase - Start basic sequence
    // =====================================================================
    virtual task run_phase(uvm_phase phase);
        axi4_base_seq base_seq;

        phase.raise_objection(this);

        `uvm_info(get_type_name(), "Starting axi4_base_test", UVM_LOW)

        base_seq = axi4_base_seq::type_id::create("base_seq");
        base_seq.start(env.virtual_seqr);

        phase.drop_objection(this);
    endtask

    // Report
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "axi4_base_test finished", UVM_LOW)
    endfunction

endclass : axi4_base_test