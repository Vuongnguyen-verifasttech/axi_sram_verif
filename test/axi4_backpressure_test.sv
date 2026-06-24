`timescale 1ns/1ps

// =============================================================================
// axi4_backpressure_test.sv
//
// Test 2 phase:
//   Phase 1 — LOW  backpressure (bp_pct = 20%) : warm-up, verify cơ bản
//   Phase 2 — HIGH backpressure (bp_pct = 80%) : stress, dễ lộ deadlock
//
// Timeout: uvm_objection set_drain_time + set_timeout
//   - Nếu DUT deadlock thì objection không drop → timeout bắt → test FAIL
// =============================================================================

class axi4_backpressure_test extends uvm_test;

    `uvm_component_utils(axi4_backpressure_test)

    // =========================================================================
    // Environment
    // =========================================================================
    axi4_env      env;
    axi4_env_cfg  env_cfg;

    // =========================================================================
    // Timeout per phase (cycles → ns, giả sử 10ns/cycle)
    // 30 trans × 8 beats × ~20 cycles/beat × backpressure overhead × 2 phase
    // =========================================================================
    localparam int unsigned PHASE_TIMEOUT_NS = 100_000;

    function new(string name = "axi4_backpressure_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =========================================================================
    // Build Phase
    // =========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Tạo và configure env_cfg
        env_cfg = axi4_env_cfg::type_id::create("env_cfg");

        if (!env_cfg.randomize())
            `uvm_fatal(get_type_name(), "env_cfg randomize failed")

        // Force scoreboard + coverage bật
        env_cfg.enable_scoreboard = 1;
        env_cfg.enable_coverage   = 1;

        // agent_cfg: enable cả 2 chiều backpressure
        env_cfg.agent_cfg.enable_write_bp = 1;
        env_cfg.agent_cfg.enable_read_bp  = 1;

        // Timeout mỗi channel — đủ rộng cho high backpressure
        env_cfg.agent_cfg.aw_timeout_cycles = 2000;
        env_cfg.agent_cfg.w_timeout_cycles  = 2000;
        env_cfg.agent_cfg.b_timeout_cycles  = 2000;
        env_cfg.agent_cfg.ar_timeout_cycles = 2000;
        env_cfg.agent_cfg.r_timeout_cycles  = 2000;

        // Push cfg vào config_db — sequence lấy qua get_full_name()
        uvm_config_db #(axi4_env_cfg)::set(this, "*", "env_cfg", env_cfg);
        uvm_config_db #(axi4_agent_cfg)::set(this, "*", "cfg",    env_cfg.agent_cfg);

        // Tạo env
        env = axi4_env::type_id::create("env", this);
        uvm_config_db #(axi4_env_cfg)::set(this, "env", "env_cfg", env_cfg);

    endfunction

    // =========================================================================
    // Run Phase
    // =========================================================================
    virtual task run_phase(uvm_phase phase);

        axi4_backpressure_seq seq;
        uvm_objection         obj;

        obj = phase.get_objection();
        obj.set_drain_time(this, 200ns);          // Cho pipeline flush sau mỗi phase
        obj.set_report_verbosity_level(UVM_MEDIUM);

        phase.raise_objection(this, "backpressure_test start");

        // =====================================================================
        // Phase 1 — LOW backpressure (20%)
        // Mục đích: verify basic correctness với một chút stall
        // =====================================================================
        `uvm_info(get_type_name(),
            "========== PHASE 1: LOW BACKPRESSURE (20%) ==========",
            UVM_LOW)

        seq           = axi4_backpressure_seq::type_id::create("seq_low");
        seq.n_trans   = 20;
        seq.bp_pct    = 20;
        seq.bp_max_cycles = 3;

        fork
            seq.start(env.vseqr);
            begin
                #(PHASE_TIMEOUT_NS * 1ns);
                `uvm_fatal(get_type_name(),
                    "TIMEOUT: Phase 1 (LOW bp) did not complete — possible deadlock")
            end
        join_any
        disable fork;

        // Drain — đợi pipeline xả hết
        #200ns;

        // =====================================================================
        // Phase 2 — HIGH backpressure (80%)
        // Mục đích: stress test, lộ deadlock / data corruption dưới heavy stall
        // =====================================================================
        `uvm_info(get_type_name(),
            "========== PHASE 2: HIGH BACKPRESSURE (80%) ==========",
            UVM_LOW)

        seq               = axi4_backpressure_seq::type_id::create("seq_high");
        seq.n_trans       = 30;
        seq.bp_pct        = 80;
        seq.bp_max_cycles = 10;

        fork
            seq.start(env.vseqr);
            begin
                #(PHASE_TIMEOUT_NS * 1ns);
                `uvm_fatal(get_type_name(),
                    "TIMEOUT: Phase 2 (HIGH bp) did not complete — possible deadlock")
            end
        join_any
        disable fork;

        phase.drop_objection(this, "backpressure_test done");

    endtask

    // =========================================================================
    // Report Phase — tóm tắt kết quả
    // =========================================================================
    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        svr = uvm_report_server::get_server();

        if (svr.get_severity_count(UVM_FATAL)   > 0 ||
            svr.get_severity_count(UVM_ERROR)   > 0) begin
            `uvm_info(get_type_name(),
                "*** TEST FAILED — check FATAL/ERROR above ***",
                UVM_NONE)
        end else begin
            `uvm_info(get_type_name(),
                "*** TEST PASSED — backpressure OK, no deadlock, data intact ***",
                UVM_NONE)
        end
    endfunction

endclass : axi4_backpressure_test