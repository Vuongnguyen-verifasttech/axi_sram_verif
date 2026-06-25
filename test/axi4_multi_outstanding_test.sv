`timescale 1ns/1ps

// =============================================================================
// axi4_multi_outstanding_test.sv — AXI_15
//
// Chạy axi4_multi_outstanding_seq với 3 phase:
//   Phase 1: single beat  (awlen=0) — baseline ID propagation
//   Phase 2: burst        (awlen=0~7) — ID propagation qua nhiều beats
//   Phase 3: mixed ID     (fixed_id thay đổi) — verify không bị cross-ID
// =============================================================================

class axi4_multi_outstanding_test extends uvm_test;

    `uvm_component_utils(axi4_multi_outstanding_test)

    axi4_env     env;
    axi4_env_cfg env_cfg;

    localparam int unsigned PHASE_TIMEOUT_NS = 200_000;

    function new(string name = "axi4_multi_outstanding_test",
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

        env_cfg.enable_scoreboard = 1;
        env_cfg.enable_coverage   = 1;

        // Không cần backpressure — focus vào ID propagation
        env_cfg.agent_cfg.backpressure_pct        = 0;
        env_cfg.agent_cfg.max_backpressure_cycles = 0;

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "env_cfg", env_cfg);

        env = axi4_env::type_id::create("env", this);

    endfunction

    // =========================================================================
    // Helper
    // =========================================================================
    task run_outstanding_phase(logic [3:0] id,
                               int unsigned n_trans,
                               string       phase_name);

        axi4_multi_outstanding_seq seq;

        `uvm_info(get_type_name(),
            $sformatf("===== %s: id=0x%0h n_trans=%0d =====",
                phase_name, id, n_trans),
            UVM_LOW)

        seq          = axi4_multi_outstanding_seq::type_id::create(phase_name);
        seq.n_trans  = n_trans;
        seq.fixed_id = id;

        fork
            seq.start(env.virtual_seqr);
            begin
                #(PHASE_TIMEOUT_NS * 1ns);
                `uvm_fatal(get_type_name(),
                    $sformatf("TIMEOUT: %s — possible deadlock", phase_name))
            end
        join_any
        disable fork;

        #100ns;

    endtask

    // =========================================================================
    // Run Phase
    // =========================================================================
    virtual task run_phase(uvm_phase phase);

        uvm_objection obj;
        obj = phase.get_objection();
        obj.set_drain_time(this, 200ns);

        phase.raise_objection(this, "multi_outstanding_test start");

        // Phase 1 — ID=0x1, single beat, baseline
        run_outstanding_phase(.id(4'h1), .n_trans(5),  .phase_name("SINGLE_BEAT_ID1"));

        // Phase 2 — ID=0xA, burst, main test
        run_outstanding_phase(.id(4'hA), .n_trans(10), .phase_name("BURST_ID_A"));

        // Phase 3 — ID=0xF, max ID value
        run_outstanding_phase(.id(4'hF), .n_trans(8),  .phase_name("BURST_ID_F"));

        phase.drop_objection(this, "multi_outstanding_test done");

    endtask

    // =========================================================================
    // Report Phase
    // =========================================================================
    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        svr = uvm_report_server::get_server();

        if (svr.get_severity_count(UVM_FATAL) > 0 ||
            svr.get_severity_count(UVM_ERROR) > 0)
            `uvm_info(get_type_name(), "*** TEST FAILED — BID/RID mismatch or deadlock ***", UVM_NONE)
        else
            `uvm_info(get_type_name(), "*** TEST PASSED — ID propagation correct ***", UVM_NONE)

    endfunction

endclass : axi4_multi_outstanding_test