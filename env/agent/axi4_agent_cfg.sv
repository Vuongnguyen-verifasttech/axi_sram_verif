class axi4_agent_cfg extends uvm_object;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    rand int unsigned backpressure_pct;
    rand int unsigned max_backpressure_cycles;

    constraint c_bp_pct {
        backpressure_pct inside {[0:100]};
    }

    constraint c_bp_max {
        max_backpressure_cycles inside {[0:20]};
    }

    bit enable_read_bp  = 1;
    bit enable_write_bp = 1;

    bit enable_cov = 1;
    bit enable_sb  = 1;

    int unsigned aw_timeout_cycles = 1000;
    int unsigned w_timeout_cycles  = 1000;
    int unsigned b_timeout_cycles  = 1000;
    int unsigned ar_timeout_cycles = 1000;
    int unsigned r_timeout_cycles  = 1000;

    `uvm_object_utils_begin(axi4_agent_cfg)
        `uvm_field_enum(uvm_active_passive_enum,is_active,UVM_ALL_ON)

        `uvm_field_int(backpressure_pct,UVM_ALL_ON)
        `uvm_field_int(max_backpressure_cycles,UVM_ALL_ON)

        `uvm_field_int(enable_read_bp,UVM_ALL_ON)
        `uvm_field_int(enable_write_bp,UVM_ALL_ON)

        `uvm_field_int(enable_cov,UVM_ALL_ON)
        `uvm_field_int(enable_sb,UVM_ALL_ON)

        `uvm_field_int(aw_timeout_cycles,UVM_ALL_ON)
        `uvm_field_int(w_timeout_cycles,UVM_ALL_ON)
        `uvm_field_int(b_timeout_cycles,UVM_ALL_ON)
        `uvm_field_int(ar_timeout_cycles,UVM_ALL_ON)
        `uvm_field_int(r_timeout_cycles,UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name="axi4_agent_cfg");
        super.new(name);
    endfunction

endclass