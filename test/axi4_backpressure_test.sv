`timescale 1ns/1ps

// =============================================================================
// axi4_backpressure_test.sv
//
// Reuse axi4_wr_rd_integrity_seq — chỉ khác integrity_test ở bp_pct
//
// env_cfg defaults đã đủ (scoreboard=1, coverage=1, enable_bp=1, timeout=1000)
// Test chỉ cần force backpressure_pct + max_backpressure_cycles trước mỗi phase
// vì 2 field này là rand — nếu không force có thể ra 0%, không test được gì
//
// 2 phase:
//   Phase 1 — LOW  (bp_pct=20%) : warm-up, verify cơ bản dưới stall nhẹ
//   Phase 2 — HIGH (bp_pct=80%) : stress, lộ deadlock / data loss dưới stall nặng
// =============================================================================

class axi4_backpressure_test extends uvm_test;

    `uvm_component_utils(axi4_backpressure_test)

    axi4_env     env;
    axi4_env_cfg env_cfg;

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

        env_cfg = axi4_env_cfg::type_id::create("env_cfg");

        if (!env_cfg.randomize())
            `uvm_fatal(get_type_name(), "env_cfg randomize failed")

        // Chỉ cần set 2 field rand này — còn lại default đã đúng
        // bp_pct sẽ được override trước mỗi phase trong run_bp_phase()
        env_cfg.agent_cfg.backpressure_pct        = 0; // placeholder, override trong run
        env_cfg.agent_cfg.max_backpressure_cycles = 0; // placeholder, override trong run

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "env_cfg", env_cfg);

        env = axi4_env::type_id::create("env", this);

    endfunction

    // =========================================================================
    // Helper — set bp rồi run integrity seq
    // =========================================================================
    task run_bp_phase(int unsigned bp_pct,
                      int unsigned bp_max_cyc,
                      int unsigned n_trans,
                      string       phase_name);

        axi4_wr_rd_integrity_seq seq;

        // Force bp trực tiếp vào agent_cfg handle — driver đọc object này
        env_cfg.agent_cfg.backpressure_pct        = bp_pct;
        env_cfg.agent_cfg.max_backpressure_cycles = bp_max_cyc;

        `uvm_info(get_type_name(),
            $sformatf("===== %s: bp_pct=%0d%% max_cyc=%0d n_trans=%0d =====",
                phase_name, bp_pct, bp_max_cyc, n_trans),
            UVM_LOW)

        seq                  = axi4_wr_rd_integrity_seq::type_id::create(phase_name);
        seq.num_transactions = n_trans;

        fork
            seq.start(env.virtual_seqr);
            begin
                #(PHASE_TIMEOUT_NS * 1ns);
                `uvm_fatal(get_type_name(),
                    $sformatf("TIMEOUT: %s did not complete — possible deadlock",
                              phase_name))
            end
        join_any
        disable fork;

        #200ns; // drain — cho pipeline DUT xả hết

    endtask

    // =========================================================================
    // Run Phase
    // =========================================================================
    virtual task run_phase(uvm_phase phase);

        uvm_objection obj;
        obj = phase.get_objection();
        obj.set_drain_time(this, 200ns);

        phase.raise_objection(this, "backpressure_test start");

        // Phase 1 — LOW: nếu fail ở đây là bug cơ bản
        run_bp_phase(.bp_pct(20), .bp_max_cyc(3),  .n_trans(20), .phase_name("LOW_BP"));

        // Phase 2 — HIGH: nếu fail ở đây là bug chỉ lộ dưới stress
        run_bp_phase(.bp_pct(80), .bp_max_cyc(10), .n_trans(30), .phase_name("HIGH_BP"));

        phase.drop_objection(this, "backpressure_test done");

    endtask

    // =========================================================================
    // Report Phase
    // =========================================================================
    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        svr = uvm_report_server::get_server();

        if (svr.get_severity_count(UVM_FATAL) > 0 ||
            svr.get_severity_count(UVM_ERROR) > 0)
            `uvm_info(get_type_name(), "*** TEST FAILED ***", UVM_NONE)
        else
            `uvm_info(get_type_name(),
                "*** TEST PASSED — no deadlock, data intact under backpressure ***",
                UVM_NONE)

    endfunction

endclass : axi4_backpressure_test